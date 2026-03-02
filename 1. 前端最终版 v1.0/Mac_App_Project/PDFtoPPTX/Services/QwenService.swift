import Foundation
import AppKit

/// 千问API服务
class QwenService {
    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
    private let inpaintingURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/image2image/image-synthesis"
    private let analyzeTimeout: TimeInterval = 180
    private let inpaintSubmitTimeout: TimeInterval = 120
    private let downloadTimeout: TimeInterval = 60

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// 使用千问VL分析图片中的文字
    func analyzeImage(_ image: NSImage) async throws -> [QwenTextBlock] {
        // 确保分析时也使用 resize 后的图片，虽然 analyzeImage 不依赖 mask，但保持一致是个好习惯
        // 这里还是让 imageToBase64 自己处理 resize
        guard let base64Image = imageToBase64(image, resize: true, maxSize: 1400, compressionFactor: 0.6) else {
            throw QwenError.invalidImage
        }

        let prompt = """
        请分析这张图片中的所有文字，每个独立的文字行作为一个文字块，返回JSON格式的数组。每个文字块包含：
        - text: 文字内容（单行，不要合并多行）
        - x: 左上角x坐标（相对于图片宽度的比例，0-1）
        - y: 左上角y坐标（相对于图片高度的比例，0-1）
        - width: 宽度（相对于图片宽度的比例，0-1）
        - height: 高度（相对于图片高度的比例，0-1）
        - fontSize: 估计的字体大小（像素）
        - color: 文字颜色（十六进制，如"000000"）
        - bgColor: 背景颜色（十六进制，如"FFFFFF"）
        - isBold: 是否为粗体或标题（true/false）

        重要：每行文字单独作为一个文字块，不要把多行合并成一段。标题、大字通常是粗体。
        只返回JSON数组，不要其他内容。示例格式：
        [{"text":"标题","x":0.1,"y":0.05,"width":0.8,"height":0.05,"fontSize":48,"color":"000000","bgColor":"FFFFFF","isBold":true}]
        """

        let requestBody: [String: Any] = [
            "model": "qwen-vl-max",
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            ["image": "data:image/jpeg;base64,\(base64Image)"],
                            ["text": prompt]
                        ]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw QwenError.requestFailed("JSON序列化失败")
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let (data, httpResponse) = try await performRequest(request, timeout: analyzeTimeout, retries: 2)
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw QwenError.requestFailed("API请求失败(\(httpResponse.statusCode)): \(errorText)")
        }

        // 注意：analyzeImage 返回的是 [QwenTextBlock]，调用者负责转换为 TextBlock
        // 但是 ConversionViewModel 中需要 TextBlock
        // 这里方法签名返回 [QwenTextBlock]，所以转换在 ViewModel 中做？
        // 不，ViewModel 中调用的是 qwen.analyzeImage(page.image)
        // 返回的是 [QwenTextBlock]
        // 我们需要确保 ViewModel 中转换时传入了 imageSize
        
        return try parseResponse(data)
    }

    /// 使用通义万相进行图像修复（inpainting）- 去除文字
    func inpaintImage(_ image: NSImage, textBlocks: [QwenTextBlock]) async throws -> NSImage {
        // 如果没有文字块，直接返回原图
        if textBlocks.isEmpty {
            print("Inpainting: 没有检测到文字块，跳过修复")
            return image
        }

        // 1. 先统一调整图片大小
        let maxSize: CGFloat = 1920
        let resizedImage = resizeImage(image, maxSize: maxSize)

        guard let base64Image = imageToBase64(resizedImage, resize: false) else {
            throw QwenError.invalidImage
        }

        // 2. 使用调整后的图片尺寸创建Mask
        let maskImage = createMaskImage(for: resizedImage, textBlocks: textBlocks)
        guard let base64Mask = maskToBase64(maskImage) else {
            throw QwenError.invalidImage
        }

        print("Inpainting: 开始调用API，文字块数量: \(textBlocks.count)")

        // 调用通义万相 wanx2.1-imageedit API - 使用 description_edit_with_mask 功能
        let requestBody: [String: Any] = [
            "model": "wanx2.1-imageedit",
            "input": [
                "function": "description_edit_with_mask",
                "prompt": "移除遮罩区域内的文字，完美还原背景。不要添加任何新内容。",
                "base_image_url": "data:image/jpeg;base64,\(base64Image)",
                "mask_image_url": "data:image/png;base64,\(base64Mask)"
            ],
            "parameters": [
                "n": 1
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw QwenError.requestFailed("JSON序列化失败")
        }

        var request = URLRequest(url: URL(string: inpaintingURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.httpBody = jsonData

        let (data, httpResponse) = try await performRequest(request, timeout: inpaintSubmitTimeout, retries: 2)

        let responseText = String(data: data, encoding: .utf8) ?? "Unknown"
        print("Inpainting API响应 (\(httpResponse.statusCode)): \(responseText)")

        guard httpResponse.statusCode == 200 else {
            throw QwenError.requestFailed("Inpainting API错误(\(httpResponse.statusCode)): \(responseText)")
        }

        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any] else {
            print("Inpainting: 无法解析响应")
            throw QwenError.requestFailed("无法解析响应")
        }

        // 尝试直接获取结果图片（同步模式）
        if let resultURL = output["result_url"] as? String,
           let url = URL(string: resultURL),
           let imageData = try? await fetchData(url: url, timeout: downloadTimeout),
           let resultImage = NSImage(data: imageData) {
            print("Inpainting: 同步模式成功获取结果")
            return resultImage
        }

        // 如果是异步模式，获取任务ID并轮询
        if let taskId = output["task_id"] as? String {
            print("Inpainting: 任务已提交，ID: \(taskId)")
            return try await waitForInpaintingResult(taskId: taskId, originalImage: image)
        }

        print("Inpainting: 无法解析结果")
        return image
    }

    /// 使用本地OCR的精确位置进行图像修复
    func inpaintImageWithLocalBlocks(_ image: NSImage, textBlocks: [TextBlock]) async throws -> NSImage {
        if textBlocks.isEmpty {
            print("Inpainting: 没有检测到文字块，跳过修复")
            return image
        }

        // 1. 先统一调整图片大小（确保图片和Mask尺寸一致）
        let maxSize: CGFloat = 1920
        let resizedImage = resizeImage(image, maxSize: maxSize)

        // 2. 使用调整后的图片尺寸创建Mask
        // 直接使用所有 blocks 创建 mask，不再进行本地预填充，避免出现色块
        let maskImage = createMaskImageFromLocalBlocks(for: resizedImage, textBlocks: textBlocks)
        guard let base64Mask = maskToBase64(maskImage) else {
            throw QwenError.invalidImage
        }
        
        guard let base64Image = imageToBase64(resizedImage, resize: false) else {
            throw QwenError.invalidImage
        }

        print("Inpainting (本地位置): 开始调用API")
        print("  - 文字块数量: \(textBlocks.count)")
        print("  - 图片尺寸: \(resizedImage.size)")
        print("  - Mask尺寸: \(maskImage.size)")
        
        // 调试：打印前几个文字块的坐标
        for (i, block) in textBlocks.prefix(3).enumerated() {
            print("  - Block \(i): \(block.text.prefix(10))... rect=\(block.boundingBox)")
        }

        let requestBody: [String: Any] = [
            "model": "wanx2.1-imageedit",
            "input": [
                "function": "description_edit_with_mask",
                "prompt": "移除遮罩区域内的文字，完美还原背景。不要添加任何新内容。",
                "base_image_url": "data:image/jpeg;base64,\(base64Image)",
                "mask_image_url": "data:image/png;base64,\(base64Mask)"
            ],
            "parameters": [
                "n": 1
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw QwenError.requestFailed("JSON序列化失败")
        }

        var request = URLRequest(url: URL(string: inpaintingURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.httpBody = jsonData

        let (data, httpResponse) = try await performRequest(request, timeout: inpaintSubmitTimeout, retries: 2)

        let responseText = String(data: data, encoding: .utf8) ?? "Unknown"
        print("Inpainting API响应 (\(httpResponse.statusCode)): \(responseText)")

        guard httpResponse.statusCode == 200 else {
            throw QwenError.requestFailed("Inpainting API错误(\(httpResponse.statusCode)): \(responseText)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any] else {
            throw QwenError.requestFailed("无法解析响应")
        }

        if let resultURL = output["result_url"] as? String,
           let url = URL(string: resultURL),
           let imageData = try? await fetchData(url: url, timeout: downloadTimeout),
           let resultImage = NSImage(data: imageData) {
            return resultImage
        }

        if let taskId = output["task_id"] as? String {
            print("Inpainting: 任务已提交，ID: \(taskId)")
            return try await waitForInpaintingResult(taskId: taskId, originalImage: image)
        }

        return image
    }

    /// 使用本地OCR位置创建mask图像
    private func createMaskImageFromLocalBlocks(for image: NSImage, textBlocks: [TextBlock]) -> NSImage {
        let size = image.size
        let maskImage = NSImage(size: size)

        maskImage.lockFocus()

        // 黑色背景（保留区域）
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        // 白色填充文字区域（要擦除的区域）
        NSColor.white.setFill()
        for block in textBlocks {
            let blockHeightPx = block.boundingBox.height * size.height
            
            // 基础 padding：适当增大以覆盖边缘残留
            var padding = max(12, min(32, blockHeightPx * 0.6))
            
            // 如果是长条形（宽/高 > 3.5），增加 padding 以覆盖可能的背景框
            let aspectRatio = block.boundingBox.width / block.boundingBox.height
            if aspectRatio > 3.5 {
                padding = padding * 1.4
            }
            
            // 限制最大 padding，防止过度覆盖
            padding = min(padding, 45)
            
            let rect = NSRect(
                x: block.boundingBox.minX * size.width - padding,
                y: (1 - block.boundingBox.maxY) * size.height - padding,
                width: block.boundingBox.width * size.width + padding * 2,
                height: block.boundingBox.height * size.height + padding * 2
            )
            let radius = max(4, min(16, padding * 0.5))
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }

        maskImage.unlockFocus()

        return maskImage
    }

    private func isLightBackground(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return false }
        let r = rgb.redComponent
        let g = rgb.greenComponent
        let b = rgb.blueComponent
        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let chroma = max(r, max(g, b)) - min(r, min(g, b))
        return l >= 0.80 && chroma <= 0.18
    }


    /// 将mask图像转换为PNG格式的base64（mask需要PNG格式保持透明度）
    private func maskToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }

    /// 等待inpainting任务完成
    private func waitForInpaintingResult(taskId: String, originalImage: NSImage) async throws -> NSImage {
        let statusURL = "https://dashscope.aliyuncs.com/api/v1/tasks/\(taskId)"

        for i in 0..<30 {  // 最多等待30次，每次2秒
            try await Task.sleep(nanoseconds: 2_000_000_000)

            var request = URLRequest(url: URL(string: statusURL)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, httpResponse) = try await performRequest(request, timeout: 30, retries: 1)
            if httpResponse.statusCode != 200 {
                continue
            }
            let responseText = String(data: data, encoding: .utf8) ?? "Unknown"
            print("Inpainting 轮询 \(i+1)/30: \(responseText)")

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let output = json["output"] as? [String: Any],
                  let taskStatus = output["task_status"] as? String else {
                print("Inpainting: 无法解析轮询响应")
                continue
            }

            print("Inpainting 任务状态: \(taskStatus)")

            if taskStatus == "SUCCEEDED" {
                if let results = output["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let imageURL = firstResult["url"] as? String,
                   let url = URL(string: imageURL),
                   let imageData = try? await fetchData(url: url, timeout: downloadTimeout),
                   let resultImage = NSImage(data: imageData) {
                    print("Inpainting: 成功获取修复后的图片")
                    return resultImage
                }
                print("Inpainting: 任务成功但无法获取图片")
            } else if taskStatus == "FAILED" {
                let errorMsg = output["message"] as? String ?? "未知错误"
                print("Inpainting: 任务失败 - \(errorMsg)")
                break
            }
        }

        print("Inpainting: 超时或失败，返回原图")
        return originalImage
    }

    /// 创建mask图像（白色区域为需要修复的部分）
    private func createMaskImage(for image: NSImage, textBlocks: [QwenTextBlock]) -> NSImage {
        let size = image.size
        let maskImage = NSImage(size: size)

        maskImage.lockFocus()

        // 黑色背景
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        // 白色填充文字区域
        NSColor.white.setFill()
        for block in textBlocks {
            let rect = NSRect(
                x: block.x * size.width - 5,
                y: (1 - block.y - block.height) * size.height - 5,
                width: block.width * size.width + 10,
                height: block.height * size.height + 10
            )
            NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        }

        maskImage.unlockFocus()

        return maskImage
    }

    private func imageToBase64(_ image: NSImage, resize: Bool = true, maxSize: CGFloat = 1920, compressionFactor: CGFloat = 0.7) -> String? {
        // 压缩图片到合适大小（千问API限制10MB）
        let imageToProcess: NSImage
        if resize {
            imageToProcess = resizeImage(image, maxSize: maxSize)
        } else {
            imageToProcess = image
        }

        guard let tiffData = imageToProcess.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // 使用JPEG格式压缩，质量0.7
        guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) else {
            return nil
        }

        return jpegData.base64EncodedString()
    }
    
    private func fetchData(url: URL, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await performRequest(request, timeout: timeout, retries: 2)
        return data
    }
    
    private func performRequest(_ request: URLRequest, timeout: TimeInterval, retries: Int) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0...retries {
            var req = request
            req.timeoutInterval = timeout
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    throw QwenError.requestFailed("无效的HTTP响应")
                }
                
                if http.statusCode == 429 || http.statusCode >= 500 {
                    if attempt < retries {
                        let delay = UInt64((0.8 * pow(2.0, Double(attempt))) * 1_000_000_000)
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                }
                
                return (data, http)
            } catch {
                lastError = error
                
                if let urlError = error as? URLError {
                    if urlError.code == .timedOut {
                        if attempt < retries {
                            let delay = UInt64((0.8 * pow(2.0, Double(attempt))) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: delay)
                            continue
                        }
                        throw QwenError.timeout
                    }
                    
                    let retryable: Set<URLError.Code> = [
                        .networkConnectionLost,
                        .notConnectedToInternet,
                        .cannotConnectToHost,
                        .cannotFindHost,
                        .dnsLookupFailed
                    ]
                    
                    if retryable.contains(urlError.code), attempt < retries {
                        let delay = UInt64((0.8 * pow(2.0, Double(attempt))) * 1_000_000_000)
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                }
                
                if attempt < retries {
                    let delay = UInt64((0.8 * pow(2.0, Double(attempt))) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                
                throw QwenError.requestFailed(error.localizedDescription)
            }
        }
        
        throw QwenError.requestFailed(lastError?.localizedDescription ?? "未知错误")
    }

    private func resizeImage(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)

        if scale >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)

        newImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize),
                   from: CGRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }

    private func parseResponse(_ data: Data) throws -> [QwenTextBlock] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            throw QwenError.parseFailed("无法解析响应")
        }

        // 找到文本内容
        guard let textContent = content.first(where: { $0["text"] != nil }),
              let text = textContent["text"] as? String else {
            throw QwenError.parseFailed("响应中没有文本内容")
        }

        // 提取JSON数组
        guard let jsonStart = text.firstIndex(of: "["),
              let jsonEnd = text.lastIndex(of: "]") else {
            throw QwenError.parseFailed("响应中没有JSON数组")
        }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8),
              let blocks = try? JSONDecoder().decode([QwenTextBlock].self, from: jsonData) else {
            throw QwenError.parseFailed("JSON解析失败")
        }
        
        // 获取图片尺寸用于计算字体比例
        // analyzeImage 传入了 image，但 parseResponse 只有 data
        // 我们需要改变 parseResponse 的签名或者在 analyzeImage 中处理转换
        // 这里直接返回 QwenTextBlock，转换在 analyzeImage 中做
        return blocks
    }

    private func extractImageFromResponse(_ data: Data) throws -> NSImage? {
        // 千问VL可能返回图片URL或base64
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        // 查找图片内容
        for item in content {
            if let imageURL = item["image"] as? String {
                if imageURL.hasPrefix("data:image") {
                    // Base64图片
                    let base64 = imageURL.components(separatedBy: ",").last ?? ""
                    if let imageData = Data(base64Encoded: base64) {
                        return NSImage(data: imageData)
                    }
                } else {
                    // URL图片
                    if let url = URL(string: imageURL),
                       let imageData = try? Data(contentsOf: url) {
                        return NSImage(data: imageData)
                    }
                }
            }
        }

        return nil
    }
}

/// 千问识别的文字块
struct QwenTextBlock: Codable {
    let text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let fontSize: Double
    let color: String
    let bgColor: String
    let isBold: Bool

    /// 转换为TextBlock
    func toTextBlock(imageSize: CGSize) -> TextBlock {
        // 千问返回的坐标：y从顶部开始（0在顶部）
        let boundingBox = CGRect(x: x, y: y, width: width, height: height)
        let textColor = NSColor(hex: color) ?? .black
        let backgroundColor = NSColor(hex: bgColor) ?? .white
        
        let ratio = max(CGFloat(fontSize) / imageSize.height, CGFloat(height) * 0.85)

        return TextBlock(
            text: text,
            confidence: 1.0,
            boundingBox: boundingBox,
            fontSizeRatio: ratio,
            textColor: textColor,
            backgroundColor: backgroundColor,
            isBold: isBold,
            rotation: 0, // 千问暂未返回旋转角度，默认为0
            strokeColor: nil, // 千问暂未返回描边信息
            strokeWidth: nil
        )
    }
}

enum QwenError: Error, LocalizedError {
    case invalidImage
    case requestFailed(String)
    case parseFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图片"
        case .requestFailed(let msg):
            return "请求失败: \(msg)"
        case .parseFailed(let msg):
            return "解析失败: \(msg)"
        case .timeout:
            return "请求超时"
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
