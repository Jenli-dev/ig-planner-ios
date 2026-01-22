import Foundation

/// Manager for Apphud analytics integration
/// 
/// Requirements:
/// 1. Sign up at https://apphud.com/
/// 2. Get API Key from Apphud dashboard
/// 3. Add Apphud SDK via SPM or CocoaPods:
///    - SPM: https://github.com/apphud/ApphudSDK-Swift
///    - Or use REST API for server-side integration
/// 
/// Documentation: https://docs.apphud.com/
@MainActor
class ApphudManager: ObservableObject {
    static let shared = ApphudManager()
    
    @Published var isInitialized = false
    @Published var userId: String?
    
    private let apiKey: String?
    private let userIdKey = "apphud_user_id"
    
    private init() {
        // Get API key from environment or config
        // In production, use secure storage
        apiKey = ProcessInfo.processInfo.environment["APPHUD_API_KEY"]
        
        // Load saved user ID
        userId = UserDefaults.standard.string(forKey: userIdKey)
    }
    
    // MARK: - Initialization
    
    /// Initialize Apphud SDK (if using SDK)
    /// For REST API integration, this is optional
    func initialize() {
        guard let apiKey = apiKey else {
            print("⚠️ Apphud: API key not found. Set APPHUD_API_KEY environment variable.")
            return
        }
        
        // If using Apphud SDK:
        // Apphud.start(apiKey: apiKey)
        // For now, apiKey is stored but SDK is not integrated yet
        _ = apiKey // Suppress unused variable warning
        
        // For REST API integration, we'll send events directly
        isInitialized = true
        print("✅ Apphud: Initialized")
    }
    
    // MARK: - Event Tracking (REST API)
    
    /// Track subscription event
    func trackSubscriptionEvent(
        event: SubscriptionEvent,
        productId: String,
        transactionId: String,
        receipt: String? = nil
    ) async throws {
        guard let apiKey = apiKey else {
            throw NSError(
                domain: "Apphud",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apphud API key not configured"]
            )
        }
        
        let url = URL(string: "https://api.apphud.com/v1/customers/events")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "name": event.rawValue,
            "properties": [
                "product_id": productId,
                "transaction_id": transactionId
            ]
        ]
        
        if let userId = userId {
            body["user_id"] = userId
        }
        
        if let receipt = receipt {
            body["receipt"] = receipt
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "Apphud",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Apphud API error: \(errorText)"]
            )
        }
        
        // Parse response to get user ID if provided
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let userId = json["user_id"] as? String {
            self.userId = userId
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }
    }
    
    /// Track custom event
    func trackEvent(name: String, properties: [String: Any] = [:]) async throws {
        guard let apiKey = apiKey else { return }
        
        let url = URL(string: "https://api.apphud.com/v1/customers/events")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "name": name,
            "properties": properties
        ]
        
        if let userId = userId {
            body["user_id"] = userId
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "Apphud",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to track event"]
            )
        }
    }
}

// MARK: - Subscription Events

enum SubscriptionEvent: String {
    case subscriptionStarted = "subscription_started"
    case subscriptionRenewed = "subscription_renewed"
    case subscriptionCancelled = "subscription_cancelled"
    case subscriptionExpired = "subscription_expired"
    case trialStarted = "trial_started"
    case trialConverted = "trial_converted"
    case refund = "refund"
}
