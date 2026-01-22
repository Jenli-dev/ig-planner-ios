import Foundation
import AdSupport
import AppTrackingTransparency

/// Manager for Apple Search Ads attribution and API integration
/// 
/// Requirements:
/// 1. Apple Search Ads API access (https://developer.apple.com/app-store-connect/api/)
/// 2. API Key (.p8 file) from App Store Connect
/// 3. Key ID and Issuer ID from App Store Connect
/// 4. Add AdSupport.framework and AppTrackingTransparency.framework
/// 5. Add NSUserTrackingUsageDescription in Info.plist
@MainActor
class AppleSearchAdsManager: ObservableObject {
    static let shared = AppleSearchAdsManager()
    
    @Published var attributionToken: String?
    @Published var campaignId: String?
    @Published var adGroupId: String?
    @Published var keyword: String?
    
    private init() {}
    
    // MARK: - Attribution Token (iOS 14.3+)
    
    /// Request attribution token from Apple Search Ads
    /// This requires ATT permission (App Tracking Transparency)
    /// 
    /// Note: Actual attribution token comes from Apple's Search Ads Attribution API
    /// This is a placeholder - in production, use the official API or backend integration
    func requestAttributionToken() async {
        // Check if tracking is authorized
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .authorized else {
            print("⚠️ Apple Search Ads: Tracking not authorized. Status: \(status.rawValue)")
            return
        }
        
        // Get IDFA (Identifier for Advertisers)
        // Note: For actual Search Ads attribution, you need to:
        // 1. Use Apple's Search Ads Attribution API (server-side)
        // 2. Or integrate with a service like AppsFlyer, Adjust, etc.
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        attributionToken = idfa
        
        // Send to backend for processing
        do {
            try await sendAttributionToBackend()
            print("✅ Apple Search Ads: Attribution sent to backend")
        } catch {
            print("⚠️ Apple Search Ads: Failed to send attribution: \(error)")
        }
    }
    
    /// Request ATT permission (call this before requesting attribution)
    func requestTrackingPermission() async -> Bool {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        return status == .authorized
    }
    
    // MARK: - Search Ads Attribution API (Server-side)
    
    /// Send attribution data to backend for processing
    /// Backend should call Apple Search Ads Attribution API
    func sendAttributionToBackend() async throws {
        guard let token = attributionToken else {
            throw NSError(
                domain: "AppleSearchAds",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No attribution token available"]
            )
        }
        
        // Send to your backend
        let url = API.url("/analytics/search-ads/attribution")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "attribution_token": token,
            "idfa": ASIdentifierManager.shared().advertisingIdentifier.uuidString,
            "timestamp": Date().timeIntervalSince1970
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AppleSearchAds",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Backend request failed"]
            )
        }
        
        // Parse response if needed
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            campaignId = json["campaign_id"] as? String
            adGroupId = json["ad_group_id"] as? String
            keyword = json["keyword"] as? String
        }
    }
}

// MARK: - Info.plist requirement
/*
 Add this to Info.plist:
 
 <key>NSUserTrackingUsageDescription</key>
 <string>We use this to measure the effectiveness of our advertising campaigns and improve your experience.</string>
 */
