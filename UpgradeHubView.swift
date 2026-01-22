import SwiftUI

// Локальная тема для UpgradeHubView — оставляем только pill
private enum HubTheme {
    static let pill = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.33, blue: 0.55),
            Color(red: 0.92, green: 0.40, blue: 0.92),
            Color(red: 0.95, green: 0.60, blue: 0.25)
        ],
        startPoint: .leading, endPoint: .trailing
    )
}

struct UpgradeHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    private let termsURL  = URL(string: "https://jenli.net/Terms-of-Use")
    private let privacyURL = URL(string: "https://jenli.net/privacy")
    
    var body: some View {
        ZStack {
            // (удалено) HubTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Close
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .accessibilityLabel("Close")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Go Pro")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Enhance Your Profile with Tools")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 6)
                    
                    // Cards grid
                    VStack(spacing: 14) {
                        featureCard(
                            icon: "person.crop.circle.badge.xmark",
                            title: "Not Follow Me Back",
                            subtitle: "Who isn’t interested in you"
                        )
                        HStack(spacing: 14) {
                            featureCard(
                                icon: "eye.trianglebadge.exclamationmark",
                                title: "View but not follow",
                                subtitle: "Who is interested in me"
                            )
                            featureCard(
                                icon: "heart.slash",
                                title: "Lost interest",
                                subtitle: "No longer active"
                            )
                        }
                        HStack(spacing: 14) {
                            featureCard(
                                icon: "person.crop.circle.badge.plus",
                                title: "New Followers",
                                subtitle: "Recently appeared"
                            )
                            featureCard(
                                icon: "person.crop.circle.badge.minus",
                                title: "Lost Followers",
                                subtitle: "Recently appeared"
                            )
                        }
                        HStack(spacing: 14) {
                            featureCard(
                                icon: "theatermasks",
                                title: "Ghost Followers",
                                subtitle: "Who is inactive"
                            )
                            featureCard(
                                icon: "person.2",
                                title: "Active Followers",
                                subtitle: "Who interacts with you"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // CTA
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Continue & Subscribe")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(HubTheme.pill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    
                    // Footer links
                    HStack(spacing: 18) {
                        if let termsURL {
                            Link("Terms of Use", destination: termsURL)
                                .foregroundColor(.white.opacity(0.9))
                                .font(.footnote)
                        }
                        Divider().frame(height: 12).background(Color.white.opacity(0.25))
                        if let privacyURL {
                            Link("Privacy Policy", destination: privacyURL)
                                .foregroundColor(.white.opacity(0.9))
                                .font(.footnote)
                        }
                        Divider().frame(height: 12).background(Color.white.opacity(0.25))
                        Button("Restore") {
                            Task { await PurchaseManager.shared.restore() }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .padding(.top, 6)
            }
        }
        .brandBackground()  // ← единый брендовый фон
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainer {
                showPaywall = false
            } onSubscribed: {
                showPaywall = false
            }
        }
    }
    
    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30, alignment: .center)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
