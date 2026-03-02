import Foundation
import AppKit
import SwiftUI

/// 后端 API 服务
/// 通过后端代理调用 Nano API，确保 API Key 安全
final class BackendAPIService {
    
    // MARK: - 错误类型
    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidImage
        case requestFailed(String)
        case insufficientCredits(required: Int, available: Int)
        case userNotFound
        case timedOut
        case invalidResponse(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "服务器 URL 无效"
            case .invalidImage:
                return "图片编码失败"
            case .requestFailed(let message):
                return "请求失败: \(message)"
            case .insufficientCredits(let required, let available):
                return "积分不足：需要 \(required) 积分，当前余额 \(available)"
            case .userNotFound:
                return "用户不存在，请先登录"
            case .timedOut:
                return "请求超时"
            case .invalidResponse(let details):
                return "响应格式异常: \(details)"
            }
        }
    }
    
    // MARK: - 单例
    static let shared = BackendAPIService()
    
    // MARK: - 配置
    /// 后端服务器地址（可在设置中修改）
    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "BackendBaseURL") ?? "https://ehotapp.xyz" }
        set { UserDefaults.standard.set(newValue, forKey: "BackendBaseURL") }
    }
    
    /// 当前登录用户手机号
    var phoneNumber: String? {
        get { UserDefaults.standard.string(forKey: "UserPhoneNumber") }
        set { UserDefaults.standard.set(newValue, forKey: "UserPhoneNumber") }
    }
    
    /// 是否已登录
    var isLoggedIn: Bool {
        return phoneNumber != nil && !phoneNumber!.isEmpty
    }
    
    private init() {}
    
    // MARK: - API 方法
    
    /// 图片修复 - 调用后端代理的 Nano API
    /// - Parameters:
    ///   - image: 原始图片
    ///   - mask: Mask 图片（白色区域为需要擦除的部分）
    /// - Returns: 处理后的图片
    func inpaint(image: NSImage, mask: NSImage) async throws -> NSImage {
        guard let phone = phoneNumber, !phone.isEmpty else {
            throw APIError.userNotFound
        }
        
        // 构建 multipart/form-data 请求
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/mac/inpaint")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 修图可能需要较长时间，匹配服务器超时
        
        var body = Data()
        
        // 添加图片
        if let imageData = encodeImage(image) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // 添加 mask
        if let maskData = encodeImage(mask) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(maskData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // 添加手机号
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"phone_number\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(phone)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效的 HTTP 响应")
        }
        
        // Check for Nginx-level errors BEFORE trying to parse JSON
        if http.statusCode == 413 {
            throw APIError.requestFailed("PDF 文件过大，请尝试压缩后重新上传（建议单文件不超过 50MB）")
        }
        if http.statusCode == 504 {
            throw APIError.requestFailed("服务器处理超时，PDF 页数过多或内容过于复杂，请尝试减少页数后重试")
        }
        if http.statusCode == 502 {
            throw APIError.requestFailed("服务器暂时不可用，请稍后重试")
        }
        
        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Don't dump raw HTML into error messages
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? ""
            if preview.contains("<html") || preview.contains("<!DOCTYPE") {
                throw APIError.requestFailed("服务器返回了非预期的响应（HTTP \(http.statusCode)），请稍后重试")
            }
            throw APIError.invalidResponse("无法解析服务器响应")
        }
        
        // 处理错误
        if http.statusCode == 402 {
            let _ = json["detail"] as? String ?? ""
            // 解析积分信息
            throw APIError.insufficientCredits(required: 1, available: 0)
        }
        
        if http.statusCode == 404 {
            throw APIError.userNotFound
        }
        
        if http.statusCode != 200 {
            let detail = json["detail"] as? String ?? "未知错误"
            throw APIError.requestFailed(detail)
        }
        
        // 解析成功响应
        guard let imageBase64 = json["image_base64"] as? String,
              let imageData = Data(base64Encoded: imageBase64),
              let resultImage = NSImage(data: imageData) else {
            throw APIError.invalidResponse("无法解析返回的图片")
        }
        
        // 更新本地积分缓存（可选）
        if let remaining = json["remaining_credits"] as? Int {
            cachedCredits = remaining
        }
        
        return resultImage
    }
    
    /// 查询积分余额
    func getCredits() async throws -> Int {
        guard let phone = phoneNumber, !phone.isEmpty else {
            throw APIError.userNotFound
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/mac/credits")!
        urlComponents.queryItems = [URLQueryItem(name: "phone_number", value: phone)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效的 HTTP 响应")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse(String(data: data, encoding: .utf8) ?? "")
        }
        
        if http.statusCode == 404 {
            throw APIError.userNotFound
        }
        
        if http.statusCode != 200 {
            let detail = json["detail"] as? String ?? "未知错误"
            throw APIError.requestFailed(detail)
        }
        
        guard let credits = json["credits"] as? Int else {
            throw APIError.invalidResponse("无法解析积分")
        }
        
        cachedCredits = credits
        return credits
    }
    
    /// 验证用户登录状态
    func verifyToken() async throws -> Bool {
        guard let phone = phoneNumber, !phone.isEmpty else {
            return false
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/mac/verify-token")!
        urlComponents.queryItems = [URLQueryItem(name: "phone_number", value: phone)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            
            if http.statusCode == 404 {
                return false
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            
            if let valid = json["valid"] as? Bool {
                if valid, let credits = json["credits"] as? Int {
                    cachedCredits = credits
                }
                return valid
            }
            
            return false
        } catch {
            return false
        }
    }
    
    /// 兑换积分码
    /// - Parameter code: 兑换码
    /// - Returns: (成功获得的积分, 提示消息)
    func redeemCode(_ code: String) async throws -> (points: Int, message: String) {
        guard let phone = phoneNumber, !phone.isEmpty else {
            throw APIError.userNotFound
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/api/codes/redeem")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "code": code,
            "phone_number": phone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效的响应")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse(String(data: data, encoding: .utf8) ?? "")
        }
        
        if http.statusCode != 200 {
            let detail = json["detail"] as? String ?? "兑换失败"
            throw APIError.requestFailed(detail)
        }
        
        // 解析返回的积分信息
        let message = json["message"] as? String ?? "兑换成功"
        var points = 0
        if let codeInfo = json["code"] as? [String: Any] {
            points = codeInfo["points"] as? Int ?? 0
        }
        
        // 刷新积分缓存
        _ = try? await getCredits()
        
        return (points, message)
    }
    
    /// 登出
    func logout() {
        phoneNumber = nil
        cachedCredits = nil
    }
    
    // MARK: - 支付相关
    struct HupijiaoOrderResponse: Codable {
        let orderId: String
        let paymentUrl: String
        
        enum CodingKeys: String, CodingKey {
            case orderId = "order_id"
            case paymentUrl = "payment_url"
        }
    }
    
    /// 创建支付订单
    func createOrder(credits: Int, amount: Double) async throws -> HupijiaoOrderResponse {
        guard let phone = phoneNumber else {
            throw APIError.userNotFound
        }
        
        let url = URL(string: "\(baseURL)/api/pay/create-order")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Match the backend OrderCreate schema
        let body: [String: Any] = [
            "user_id": phone,
            "credits": credits,
            "amount": amount,
            "status": "pending"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse("无效响应")
        }
        
        if http.statusCode != 200 {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let detail = json?["detail"] as? String ?? "Unknown error"
            throw APIError.requestFailed("创建订单失败: \(detail)")
        }
        
        do {
            let orderResponse = try JSONDecoder().decode(HupijiaoOrderResponse.self, from: data)
            return orderResponse
        } catch {
            print("Decoding error: \(error)")
            throw APIError.invalidResponse("API 响应解析失败")
        }
    }
    
    /// 查询订单状态
    func checkOrderStatus(orderId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/pay/status/\(orderId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let detail = json?["detail"] as? String ?? "Failed to check status"
            throw APIError.requestFailed("查询订单状态失败: \(detail)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String else {
            throw APIError.invalidResponse("Invalid status response")
        }
        
        return status == "completed"
    }
    
    // MARK: - 积分缓存
    private(set) var cachedCredits: Int? = nil {
        didSet {
            if oldValue != cachedCredits {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("CreditsUpdated"), object: nil)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func encodeImage(_ image: NSImage) -> Data? {
        let maxDimension: CGFloat = 2048
        let originalSize = image.size
        
        // Calculate scale factor if resizing is needed
        var targetSize = originalSize
        let longerSide = max(originalSize.width, originalSize.height)
        if longerSide > maxDimension {
            let scale = maxDimension / longerSide
            targetSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        }
        
        // Create resized image
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Encode as JPEG for smaller file size
        guard let tiff = resizedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}

// MARK: - App Update Support

struct AppVersion: Codable {
    let version: String
    let build: Int
    let download_url: String
    let release_notes: String?
    let force_update: Bool
}

class UpdateService: ObservableObject {
    static let shared = UpdateService()
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    private var downloadedDMGPath: String?
    
    func checkForUpdates(isUserInitiated: Bool = false) {
        guard let url = URL(string: "\(BackendAPIService.shared.baseURL)/api/v1/misc/app/latest") else {
            if isUserInitiated { DispatchQueue.main.async { self.showErrorAlert(message: "服务器地址无效") } }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                if isUserInitiated { DispatchQueue.main.async { self?.showErrorAlert(message: "无法连接到服务器") } }
                return
            }
            do {
                let remoteVersion = try JSONDecoder().decode(AppVersion.self, from: data)
                self.compareVersions(remoteVersion: remoteVersion, isUserInitiated: isUserInitiated)
            } catch {
                print("Update check decode error: \(error)")
                if isUserInitiated { DispatchQueue.main.async { self.showErrorAlert(message: "版本数据解析失败") } }
            }
        }.resume()
    }
    
    private func compareVersions(remoteVersion: AppVersion, isUserInitiated: Bool) {
        let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        guard let currentBuildStr = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let currentBuild = Int(currentBuildStr) else { return }
        
        let versionComparison = compareSemanticVersion(remoteVersion.version, currentVersion)
        print("[UpdateService] Current Version: \(currentVersion) (\(currentBuild)), Remote Version: \(remoteVersion.version) (\(remoteVersion.build))")

        if versionComparison > 0 || (versionComparison == 0 && remoteVersion.build > currentBuild) {
            self.startBackgroundDownload(for: remoteVersion, isUserInitiated: isUserInitiated)
        } else {
            if isUserInitiated {
                DispatchQueue.main.async { self.showNoUpdateAlert() }
            }
        }
    }

    private func compareSemanticVersion(_ lhs: String, _ rhs: String) -> Int {
        let lParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lParts.count, rParts.count)
        for index in 0..<count {
            let l = index < lParts.count ? lParts[index] : 0
            let r = index < rParts.count ? rParts[index] : 0
            if l > r { return 1 }
            if l < r { return -1 }
        }
        return 0
    }
    
    // MARK: - Download & Install
    
    private func startBackgroundDownload(for version: AppVersion, isUserInitiated: Bool) {
        guard !isDownloading else { return }
        
        let urlString = "\(BackendAPIService.shared.baseURL)\(version.download_url)"
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            if isUserInitiated {
                let alert = NSAlert()
                alert.messageText = "发现新版本"
                alert.informativeText = "新版本 (Build \(version.build)) 正在后台下载。下载完成后将提示您重启安装。"
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }
        }
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isDownloading = false
            }
            
            guard let localURL = localURL, error == nil else {
                if isUserInitiated {
                    DispatchQueue.main.async { self.showErrorAlert(message: "下载更新失败，请稍后重试。") }
                }
                return
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let destURL = tempDir.appendingPathComponent("NotePDF2PPT_Update_\(version.build).dmg")
            
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destURL)
                self.downloadedDMGPath = destURL.path
                
                DispatchQueue.main.async {
                    self.promptForInstall(version: version.version, build: version.build)
                }
            } catch {
                print("Failed to move downloaded update: \(error)")
                if isUserInitiated {
                    DispatchQueue.main.async { self.showErrorAlert(message: "保存更新文件失败") }
                }
            }
        }
        task.resume()
    }
    
    private func promptForInstall(version: String, build: Int) {
        let alert = NSAlert()
        alert.messageText = "新版本已准备就绪"
        alert.informativeText = "NotePDF 2 PPT v\(version) (Build \(build)) 已经下载完成。是否立即重启并安装更新？"
        alert.addButton(withTitle: "立即重启并更新")
        alert.addButton(withTitle: "稍后")
        
        if alert.runModal() == .alertFirstButtonReturn {
            installUpdateAndRestart()
        }
    }
    
    private func installUpdateAndRestart() {
        guard let dmgPath = downloadedDMGPath else { return }
        
        let currentAppPath = Bundle.main.bundlePath
        let appName = (currentAppPath as NSString).lastPathComponent
        
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("install_update.sh").path
        let mountDir = "/tmp/NotePDF2PPT_Update_Mount"
        
        let scriptContent = """
        #!/bin/bash
        sleep 2
        
        DMG_PATH="\(dmgPath)"
        MOUNT_DIR="\(mountDir)"
        APP_DEST="\(currentAppPath)"
        APP_NAME="\(appName)"
        
        # Detach if previously mounted
        hdiutil detach "$MOUNT_DIR" -force 2>/dev/null
        
        # Mount DMG safely to specific directory without verification dialogs
        hdiutil attach "$DMG_PATH" -nobrowse -noverify -noautoopen -mountpoint "$MOUNT_DIR"
        
        if [ -d "$MOUNT_DIR/$APP_NAME" ]; then
            rm -rf "$APP_DEST"
            cp -R "$MOUNT_DIR/$APP_NAME" "$(dirname "$APP_DEST")/"
            hdiutil detach "$MOUNT_DIR" -force
            open "$APP_DEST"
            rm -f "$DMG_PATH"
        else
            # Fallback if name mismatches
            APP_SRC=$(find "$MOUNT_DIR" -maxdepth 1 -name "*.app" -print -quit)
            if [ -n "$APP_SRC" ]; then
                rm -rf "$APP_DEST"
                cp -R "$APP_SRC" "$(dirname "$APP_DEST")/"
                hdiutil detach "$MOUNT_DIR" -force
                open "$(dirname "$APP_DEST")/$(basename "$APP_SRC")"
                rm -f "$DMG_PATH"
            else
                hdiutil detach "$MOUNT_DIR" -force
            fi
        fi
        
        rm -f "$0"
        """
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            var attributes = try FileManager.default.attributesOfItem(atPath: scriptPath)
            attributes[.posixPermissions] = NSNumber(value: 0o755)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
            
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [scriptPath]
            
            if #available(macOS 10.13, *) {
                try process.run()
            } else {
                process.launch() // Deprecated fallback
            }
            
            // Terminate current instance to let script proceed
            NSApplication.shared.terminate(nil)
        } catch {
            print("Failed to run update script: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "当前已是最新版本"
        alert.informativeText = "您正在使用最新的 NotePDF 2 PPT。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "更新失败"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
