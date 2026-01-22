import Foundation
import SwiftUI

/// Manager for Adapty integration
/// 
/// Requirements:
/// 1. Sign up at https://adapty.io/
/// 2. Get API Key from Adapty dashboard
/// 3. Add Adapty SDK via SPM:
///    Package URL: https://github.com/adapty/AdaptySDK-iOS
///    Version: 2.7.0+
/// 
/// Features:
/// - A/B testing for paywalls
/// - Onboarding flows
/// - Product metrics
/// - Revenue analytics
/// 
/// Documentation: https://docs.adapty.io/
@MainActor
class AdaptyManager: ObservableObject {
    static let shared = AdaptyManager()
    
    @Published var isInitialized = false
    @Published var paywalls: [AdaptyPaywall] = []
    @Published var currentPaywall: AdaptyPaywall?
    @Published var profile: AdaptyProfile?
    
    private let apiKey: String?
    
    private init() {
        // Get API key from environment or config
        apiKey = ProcessInfo.processInfo.environment["ADAPTY_API_KEY"]
    }
    
    // MARK: - Initialization
    
    /// Initialize Adapty SDK
    /// Call this in AppDelegate or SceneDelegate
    func initialize(userId: String? = nil) async throws {
        guard let apiKey = apiKey else {
            throw NSError(
                domain: "Adapty",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Adapty API key not found. Set ADAPTY_API_KEY environment variable."]
            )
        }
        
        // If using Adapty SDK:
        // Adapty.activate(apiKey, customerUserId: userId)
        // For now, apiKey is stored but SDK is not integrated yet
        _ = apiKey // Suppress unused variable warning
        
        // For REST API integration:
        try await loadPaywalls()
        isInitialized = true
        print("✅ Adapty: Initialized")
    }
    
    // MARK: - Paywalls (REST API)
    
    /// Load paywalls from Adapty
    func loadPaywalls() async throws {
        guard let apiKey = apiKey else { return }
        
        let url = URL(string: "https://api.adapty.io/api/v2/sdk/paywalls")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "Adapty",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load paywalls"]
            )
        }
        
        // Parse paywalls
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let paywallsData = json["data"] as? [[String: Any]] {
            paywalls = paywallsData.compactMap { AdaptyPaywall(from: $0) }
            
            // Set first paywall as current (or use A/B test logic)
            currentPaywall = paywalls.first
        }
    }
    
    /// Get paywall for A/B testing
    func getPaywall(placementId: String? = nil) -> AdaptyPaywall? {
        // A/B testing logic: Adapty SDK handles this automatically
        // For REST API, you can implement custom logic here
        return currentPaywall
    }
    
    // MARK: - Profile & Analytics
    
    /// Get user profile from Adapty
    func getProfile() async throws {
        guard let apiKey = apiKey else { return }
        
        // Adapty SDK: Adapty.getProfile { result in ... }
        // For REST API, implement custom call
        _ = apiKey // Suppress unused variable warning
    }
    
    /// Track event for analytics
    func trackEvent(name: String, params: [String: Any] = [:]) async throws {
        guard let apiKey = apiKey else { return }
        
        // Adapty SDK: Adapty.logShowPaywall(paywall)
        // For REST API, implement custom tracking
        _ = apiKey // Suppress unused variable warning
    }
}

// MARK: - Models

struct AdaptyPaywall: Identifiable {
    let id: String
    let name: String
    let products: [AdaptyProduct]
    let abTestName: String?
    let revision: Int
    
    init?(from dict: [String: Any]) {
        guard let id = dict["developer_id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.abTestName = dict["ab_test_name"] as? String
        self.revision = dict["revision"] as? Int ?? 0
        
        // Parse products
        if let productsData = dict["products"] as? [[String: Any]] {
            self.products = productsData.compactMap { AdaptyProduct(from: $0) }
        } else {
            self.products = []
        }
    }
}

struct AdaptyProduct: Identifiable {
    let id: String
    let vendorProductId: String
    let price: String
    let currencyCode: String
    
    init?(from dict: [String: Any]) {
        guard let id = dict["vendor_product_id"] as? String else {
            return nil
        }
        
        self.id = id
        self.vendorProductId = id
        self.price = dict["price"] as? String ?? "0"
        self.currencyCode = dict["currency_code"] as? String ?? "USD"
    }
}

struct AdaptyProfile {
    let profileId: String
    let customerUserId: String?
    let accessLevels: [String: AdaptyAccessLevel]
}

struct AdaptyAccessLevel {
    let id: String
    let isActive: Bool
    let vendorProductId: String?
    let expiresAt: Date?
}
