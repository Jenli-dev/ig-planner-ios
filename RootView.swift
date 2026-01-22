import SwiftUI
import StoreKit

struct RootView: View {
    @AppStorage("seenOnboarding") private var seenOnboarding = false
    @AppStorage("didShowPaywallOnce") private var didShowPaywallOnce = false

    @EnvironmentObject var purchases: PurchaseManager
    @State private var showPaywall = false

    var body: some View {
        Group {
            if !seenOnboarding {
                OnboardingView(
                    onFinish: {
                        // Onboarding сам показал первичный пейвол и сам выставил seenOnboarding
                        // Здесь ничего дополнительно не делаем
                    },
                    onSubscribe: {
                        // тоже обрабатывается внутри OnboardingView через sheet
                    }
                )
            } else {
                MainTabView()
             //   IGConnectDemoView()//
            }
        }
        // ВТОРИЧНЫЙ пейвол (экран выбора планов) — один раз после онбординга, если не Pro
        .sheet(isPresented: $showPaywall) {
            PaywallContainer(mode: .secondary)
                .interactiveDismissDisabled(purchases.isPro == false)
        }
        .onChange(of: purchases.isPro, initial: false) { _, isPro in
            if isPro {
                showPaywall = false
                didShowPaywallOnce = true
            }
        }
        .task {
            await purchases.loadProducts()
            purchases.startTransactionObserver()

            // если онбординг уже пройден, пользователь ещё не Pro
            // и вторичный пейвол ещё ни разу не показывали — покажем его
            if seenOnboarding, !purchases.isPro, !didShowPaywallOnce {
                showPaywall = true
            }
        }
    }
}
