import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var localization: LocalizationManager
    @State private var showPaywall = false
    @State private var showLanguagePicker = false

    @State private var healthStatus = "—"
    @State private var healthInFlight = false
    @State private var healthText: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerTitle
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    // PRO / Free карточка статуса
                    StatusCard(isPro: purchases.isPro) {
                        if !purchases.isPro { showPaywall = true }
                    }

                    // блок подписки
                    SectionCard(title: nil) {
                        if purchases.isPro {
                            RowButton(
                                title: "settings.manage_subscription".localized,
                                subtitle: "settings.manage_subscription.subtitle".localized,
                                systemImage: "gearshape.2.fill"
                            ) {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } else {
                            RowGradientButton(
                                title: "settings.go_pro".localized,
                                subtitle: "settings.go_pro.subtitle".localized,
                                systemImage: "star.fill"
                            ) {
                                showPaywall = true
                            }
                        }

                        RowButton(
                            title: "settings.restore_purchases".localized,
                            subtitle: "settings.restore_purchases.subtitle".localized,
                            systemImage: "arrow.clockwise.circle"
                        ) {
                            Task { await purchases.restore() }
                        }
                    }
                    
                    // блок Language
                    SectionCard(title: nil) {
                        RowButton(
                            title: "settings.language".localized,
                            subtitle: "\(localization.currentLanguage.nativeName) • \(localization.currentLanguage.displayName)",
                            systemImage: "globe"
                        ) {
                            showLanguagePicker = true
                        }
                    }

                     // блок Diagnostics
                    #if DEBUG
                    SectionCard(title: "settings.diagnostics".localized) {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white.opacity(0.95))
                            Text("settings.ping_backend".localized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("common.ok".localized) {
                                Task { await pingBackend() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.18))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if let healthText, !healthText.isEmpty {
                            Text(healthText)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12)))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 10)
                        }
                    }
                    #endif
                                         
                    // блок About
                    SectionCard(title: "settings.about".localized) {
                        RowLink(
                            title: "settings.terms_of_use".localized,
                            systemImage: "doc.text",
                            url: URL(string: "https://jenli.net/Terms-of-Use")!
                        )
                        RowLink(
                            title: "settings.privacy_policy".localized,
                            systemImage: "lock.doc",
                            url: URL(string: "https://jenli.net/privacy")!
                        )
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 8) }
            }
        }
        .brandBackground()
        .sheet(isPresented: $showPaywall) {
            PaywallContainer {
                showPaywall = false        // onClose
            } onSubscribed: {
                showPaywall = false        // авто-закрытие после покупки
            }
            .interactiveDismissDisabled()
        }

        .task {
            await purchases.loadProducts()
            purchases.startTransactionObserver()
        }
        .onChange(of: purchases.isPro, initial: false) { _, newValue in
            if newValue { showPaywall = false }
        }
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task { await pingBackend() }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $localization.currentLanguage)
        }
    }

    // MARK: - Header

    private var headerTitle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("settings.title".localized)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 140, height: 4)
            }
            Spacer()
        }
    }
    // MARK: - Diagnostics helper
    private func pingBackend() async {
        healthInFlight = true
        defer { healthInFlight = false }
        do {
            let h = try await HealthAPI.ping()
            let line = "Backend: ok=\(h.ok)  ffmpeg=\(h.ffmpeg ?? false)  pillow=\(h.pillow ?? false)"
            healthText = line
            print("✅ /health -> \(line)")
        } catch {
            let err = "error: \(error.localizedDescription)"
            healthText = "Backend: \(err)"
            print("❌ /health error:", error.localizedDescription)
        }
    }
}

// MARK: - Components

private struct StatusCard: View {
    let isPro: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isPro ? Color.yellow.opacity(0.25) : Color.white.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isPro ? .yellow : .white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPro ? "status.pro_active".localized : "status.free_mode".localized)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                    Text(isPro ? "status.pro_thanks".localized
                               : "status.unlock_all".localized)
                        .foregroundColor(.white.opacity(0.75))
                        .font(.subheadline)
                }
                Spacer()
                if isPro {
                    Text("PRO")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .foregroundColor(.white)
                } else {
                    Button(action: onTap) {
                        Text("status.upgrade".localized)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [
                                    Color(red: 0.98, green: 0.33, blue: 0.55),
                                    Color(red: 0.92, green: 0.40, blue: 0.92),
                                    Color(red: 0.95, green: 0.60, blue: 0.25),
                                ], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { if !isPro { onTap() } }
    }
}

private struct SectionCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .foregroundColor(.white)
    }
}

private struct RowButton: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)
                    .opacity(0.95)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(divider, alignment: .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 54)
    }
}

private struct RowGradientButton: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.footnote).opacity(0.85)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.85)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [
                    Color(red: 0.98, green: 0.33, blue: 0.55),
                    Color(red: 0.92, green: 0.40, blue: 0.92),
                    Color(red: 0.95, green: 0.60, blue: 0.25),
                ], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RowLink: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(divider, alignment: .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 54)
    }
}
