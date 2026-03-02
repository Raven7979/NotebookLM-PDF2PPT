import Foundation
import AppKit

/// 支付服务
/// 负责处理订单创建、支付状态查询等
final class PaymentService {
    static let shared = PaymentService()
    
    private init() {}
    
    struct HupijiaoOrderResponse: Codable {
        let orderId: String
        let paymentUrl: String
        
        enum CodingKeys: String, CodingKey {
            case orderId = "order_id"
            case paymentUrl = "payment_url"
        }
    }
    
    enum PaymentError: Error, LocalizedError {
        case createOrderFailed(String)
        case paymentFailed(String)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .createOrderFailed(let msg): return "创建订单失败: \(msg)"
            case .paymentFailed(let msg): return "支付失败: \(msg)"
            case .invalidResponse: return "服务器响应无效"
            }
        }
    }
    
    /// 创建支付订单
    /// - Parameters:
    ///   - credits: 购买积分数量
    ///   - amount: 支付金额
    /// - Returns: 订单对象
    func createOrder(credits: Int, amount: Double) async throws -> HupijiaoOrderResponse {
        guard let phone = BackendAPIService.shared.phoneNumber else {
            throw PaymentError.createOrderFailed("用户未登录")
        }
        
        let url = URL(string: "\(BackendAPIService.shared.baseURL)/api/pay/create-order")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "user_id": phone,
            "credits": credits,
            "amount": amount,
            "status": "pending"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw PaymentError.invalidResponse
        }
        
        if http.statusCode != 200 {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let detail = json?["detail"] as? String ?? "Unknown error"
            throw PaymentError.createOrderFailed(detail)
        }
        
        do {
            let order = try JSONDecoder().decode(HupijiaoOrderResponse.self, from: data)
            return order
        } catch {
            throw PaymentError.invalidResponse
        }
    }
    
    /// 查询订单支付状态
    /// - Parameter orderId: 订单 ID
    /// - Returns: 是否支付成功
    func checkOrderStatus(orderId: String) async throws -> Bool {
        return try await BackendAPIService.shared.checkOrderStatus(orderId: orderId)
    }
}
