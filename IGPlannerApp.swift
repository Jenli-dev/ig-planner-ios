import SwiftUI

@main
struct IGPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView() // ← старт всегда с RootView
                .preferredColorScheme(.dark)
                .environmentObject(LocalizationManager.shared)
                .environmentObject(PurchaseManager.shared)
                .task {
                    // Initialize analytics services asynchronously (non-blocking)
                    // Request ATT permission for Apple Search Ads
                    let authorized = await AppleSearchAdsManager.shared.requestTrackingPermission()
                    if authorized {
                        await AppleSearchAdsManager.shared.requestAttributionToken()
                    }
                    
                    // Initialize Apphud (requires MainActor)
                    ApphudManager.shared.initialize()
                    
                    // Initialize Adapty
                    try? await AdaptyManager.shared.initialize()
                }
        }
    }
}
