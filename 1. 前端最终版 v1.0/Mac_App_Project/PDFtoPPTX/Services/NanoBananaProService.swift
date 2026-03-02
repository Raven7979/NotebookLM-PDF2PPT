import Foundation
import AppKit

final class NanoBananaProService {
    enum NanoError: Error, LocalizedError {
        case invalidURL
        case invalidImage
        case requestFailed(String)
        case timedOut
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Nano banana Pro URL 无效"
            case .invalidImage:
                return "图片编码失败"
            case .requestFailed(let message):
                return "Nano banana Pro 请求失败: \(message)"
            case .timedOut:
                return "Nano banana Pro 请求超时"
            case .invalidResponse(let details):
                return "Nano banana Pro 响应格式异常: \(details)"
            }
        }
    }

    private let drawURL: URL
    private let apiKey: String
    private let model: String

    init(drawURL: URL, apiKey: String, model: String) {
        self.drawURL = drawURL
        self.apiKey = apiKey
        self.model = model
    }

    func generateImage(from image: NSImage, prompt: String, aspectRatio: String = "auto", imageSize: String = "1K") async throws -> NSImage {
        // 迁移说明：
        // 原 NanoBananaProService 直接调用第三方 API，存在 Key 泄露风险。
        // 现改为调用后端代理接口，由后端负责鉴权和计费。
        // 后端接口目前忽略 mask 参数（使用 prompt），因此这里创建一个全白 mask 占位。
        
        let mask = NSImage(size: image.size)
        mask.lockFocus()
        NSColor.white.drawSwatch(in: NSRect(origin: .zero, size: image.size))
        mask.unlockFocus()
        
        do {
            return try await BackendAPIService.shared.inpaint(image: image, mask: mask)
        } catch {
            throw NanoError.requestFailed(error.localizedDescription)
        }
    }

    private func pollResult(id: String, resultURL: URL, timeoutSeconds: Int) async throws -> NSImage {
        let requestBody: [String: Any] = ["id": id]
        let data = try JSONSerialization.data(withJSONObject: requestBody)

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        var attempt = 0

        while Date() < deadline {
            attempt += 1

            var request = URLRequest(url: resultURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = data

            let (respData, http) = try await performRequest(request, timeout: 45)
            guard http.statusCode == 200 else {
                let errorText = String(data: respData, encoding: .utf8) ?? "Unknown error"
                throw NanoError.requestFailed("Result接口失败(\(http.statusCode)): \(errorText)")
            }

            let json = try parseJSONObject(from: respData)
            try validateBusinessStatus(json: json)

            if let imageURL = extractFirstResultURL(from: json) {
                return try await downloadImage(urlString: imageURL)
            }

            let sleepNs = UInt64(min(2.0, 0.5 + (Double(attempt) * 0.2)) * 1_000_000_000)
            try await Task.sleep(nanoseconds: sleepNs)
        }

        throw NanoError.timedOut
    }

    private func deriveResultURL(from drawURL: URL) throws -> URL {
        guard var components = URLComponents(url: drawURL, resolvingAgainstBaseURL: false) else {
            throw NanoError.invalidURL
        }
        components.path = "/v1/draw/result"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw NanoError.invalidURL }
        return url
    }

    private func extractFirstResultURL(from json: [String: Any]) -> String? {
        if let results = json["results"] as? [[String: Any]],
           let first = results.first,
           let url = first["url"] as? String,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let dataObj = json["data"] as? [String: Any],
           let results = dataObj["results"] as? [[String: Any]],
           let first = results.first,
           let url = first["url"] as? String,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func extractID(from json: [String: Any]) -> String? {
        if let id = json["id"] as? String, !id.isEmpty {
            return id
        }

        if let dataObj = json["data"] as? [String: Any],
           let id = dataObj["id"] as? String,
           !id.isEmpty {
            return id
        }

        return nil
    }

    private func downloadImage(urlString: String) async throws -> NSImage {
        guard let url = URL(string: urlString) else {
            throw NanoError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, http) = try await performRequest(request, timeout: 60)
        guard http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NanoError.requestFailed("下载图片失败(\(http.statusCode)): \(errorText)")
        }
        guard let image = NSImage(data: data) else {
            throw NanoError.invalidImage
        }
        return image
    }

    private func encodeImageAsDataURL(_ image: NSImage) throws -> String {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            throw NanoError.invalidImage
        }
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            throw NanoError.invalidImage
        }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private func performRequest(_ request: URLRequest, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
        var req = request
        req.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw NanoError.requestFailed("无效的HTTP响应")
            }
            return (data, http)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw NanoError.timedOut
            }
            throw NanoError.requestFailed(error.localizedDescription)
        }
    }

    private func validateBusinessStatus(json: [String: Any]) throws {
        if let code = json["code"] as? Int, code != 0 {
            let msg = (json["msg"] as? String) ?? "code=\(code)"
            throw NanoError.requestFailed(msg)
        }

        let payload = (json["data"] as? [String: Any]) ?? json
        if let status = (payload["status"] as? String)?.lowercased(), status == "failed" {
            let failureReason = payload["failure_reason"] as? String
            let error = payload["error"] as? String
            if let failureReason, !failureReason.isEmpty {
                if failureReason == "output_moderation" {
                    throw NanoError.requestFailed("输出触发内容安全审核（违规），可尝试换图或换提示词")
                }
                if failureReason == "input_moderation" {
                    throw NanoError.requestFailed("输入触发内容安全审核（违规），可尝试换图或换提示词")
                }
                throw NanoError.requestFailed("任务失败: \(failureReason)\(error.map { " (\($0))" } ?? "")")
            }
            if let error, !error.isEmpty {
                throw NanoError.requestFailed("任务失败: \(error)")
            }
            throw NanoError.requestFailed("任务失败")
        }
    }

    private func parseJSONObject(from data: Data) throws -> [String: Any] {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let json = bestEffortJSONDictionary(from: trimmed) {
            return json
        }

        throw NanoError.invalidResponse(compactPreview(data))
    }

    private func bestEffortJSONDictionary(from text: String) -> [String: Any]? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if let lastDataLine = lines.last(where: { $0.hasPrefix("data:") }) {
            let payload = lastDataLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            let slice = String(text[start...end])
            if let data = slice.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }

        return nil
    }

    private func compactPreview(_ data: Data) -> String {
        let s = (String(data: data, encoding: .utf8) ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(240))
    }
}
