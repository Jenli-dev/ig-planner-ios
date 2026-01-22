import SwiftUI

// MARK: - Onboarding (root)
struct OnboardingView: View {
    // Внешние колбэки (RootView может открыть Paywall)
    var onFinish: (() -> Void)? = nil
    var onSubscribe: (() -> Void)? = nil

    @AppStorage("seenOnboarding") private var seenOnboarding = false
    @State private var index = 0
    @State private var showPaywall = false
    
    private var isLastPage: Bool { index == pages.count - 1 }

    // Константный набор страниц (чтобы удобно читать)
    private static let pagesConst: [OBPage] = [
        .init(
            bigEmoji: "😮‍💨",
            badgeText: "NOT FOLLOW ME BACK",
            title: "Unfollowers Tracker",
            subtitle: "Track your followers, discover who’s active, and see who doesn’t follow you back",
            features: [
                .init(icon: "person.crop.circle.badge.xmark", title: "Unfollowers", subtitle: "Spot who left"),
                .init(icon: "eye.slash.fill", title: "Ghosts", subtitle: "Identify inactive audience"),
                .init(icon: "bell.badge.fill", title: "Alerts", subtitle: "Timely activity signals")
            ],
            heroKind: .plain,
            bigIcon: "onboarding_hero"
        ),
        .init(
            bigEmoji: "📊",
            badgeText: nil,
            title: "Advanced Analytics",
            subtitle: "Track growth, peaks, engagement & top posts",
            features: [
                .init(icon: "chart.pie.fill", title: "Insights", subtitle: "Unlock detailed analytics"),
                .init(icon: "bolt.heart.fill", title: "Engagement", subtitle: "See what really works"),
                .init(icon: "lock.fill", title: "Private & Secure", subtitle: "Your data stays with you")
            ],
            heroKind: .charts
        ),
        .init(
            bigEmoji: "⭐️",
            badgeText: nil,
            title: "Join Our Community",
            subtitle: "1M+ creators trust the tools we build",
            features: [
                .init(icon: "hand.thumbsup.fill", title: "Loved by creators", subtitle: "Rated ★★★★★"),
                .init(icon: "wand.and.stars", title: "Power Tools", subtitle: "Covers, filters, schedule"),
                .init(icon: "checkmark.seal.fill", title: "Safe", subtitle: "Policy-compliant methods")
            ],
            heroKind: .reviews
        ),
        .init(
            bigEmoji: "🛡️",
            badgeText: nil,
            title: "Your Account is Safe with Us",
            subtitle: "We use secure, policy-compliant methods to access your stats",
            features: [
                .init(icon: "shield.checkerboard", title: "Trust", subtitle: "Best practices"),
                .init(icon: "lock.shield.fill", title: "Confidential", subtitle: "Your data stays private"),
                .init(icon: "hand.raised.fill", title: "Compliant", subtitle: "Follows the platform rules")
            ],
            heroKind: .shield
        )
    ]

    // Удобный геттер
    private var pages: [OBPage] { Self.pagesConst }

    var body: some View {
        ZStack {
            // бренд-фон вместо локального градиента
            Color.clear

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // Пейджер
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        OBPageView(
                            page: page,
                            isFirst: i == 0,
                            onSubscribeTap: subscribeNow,
                            onContinueTap: advance
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page)
                .padding(.horizontal, 20)   // паддинг даём тут
                .frame(maxHeight: .infinity)
            }
        }
        .brandBackground()                // ← ЕДИНЫЙ ФОН
        .presentationBackground(.clear)   // если открыт как sheet — дать просвечивать
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: advance) {
                    Text(isLastPage ? "Continue & Subscribe" : "Continue")
                        .font(.system(size: 19,
                                      weight: .semibold,
                                      design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppGradient.brand) // ← фирменная «пилюля»
                        .clipShape(RoundedRectangle(cornerRadius: 20,
                                                    style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.30),
                                radius: 14,
                                y: 6)
                }

                OBFooterLinks()
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .background(Color.clear) // без фона — только inset
        }
        .sheet(isPresented: $showPaywall) {
            PaywallContainer(
                mode: .primary,
                onClose: {
                    seenOnboarding = true
                    onFinish?()
                },
                onSubscribed: {
                    seenOnboarding = true
                    onSubscribe?() ?? onFinish?()
                }
            )
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Actions
    private func advance() {
        if index < pages.count - 1 {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut) { index += 1 }
        } else {
            showPaywall = true
        }
    }

    private func subscribeNow() {
        showPaywall = true
    }

    // MARK: - Footer (Terms / Privacy / Restore)
    private struct OBFooterLinks: View {
        var body: some View {
            HStack(spacing: 16) {
                Link("Terms of Use",
                     destination: URL(string: "https://jenli.net/Terms-of-Use")!)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.25))

                Link("Privacy Policy",
                     destination: URL(string: "https://jenli.net/privacy")!)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.25))

                Button("Restore") {
                    Task { await PurchaseManager.shared.restore() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.95))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Models
    private struct OBFeature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    private enum OBHeroKind {
        case plain, charts, reviews, shield
    }
    private struct OBPage: Identifiable {
        let id = UUID()

        // Главные тексты
        let bigEmoji: String
        let badgeText: String?
        let title: String
        let subtitle: String

        // Список «фич» под заголовком
        let features: [OBFeature]

        // Какой «герой»-хедер рисуем
        var heroKind: OBHeroKind = .plain

        // Опциональные поля (чтобы не падали обращения из под-вью)
        var bigIcon: String? = nil
        var heroEmoji: String? = nil
        var primaryButtonTitle: String { "Continue" }
    }

    // MARK: - Dots (мини-индикатор прогресса внутри экрана)
    private struct PageDots: View {
        var body: some View {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Single Page (адаптивный экран)
    private struct OBPageView: View {
        let page: OBPage
        let isFirst: Bool
        var onSubscribeTap: () -> Void
        var onContinueTap: () -> Void

        var body: some View {
            GeometryReader { gr in
                let h = gr.size.height
                let compact = h < 780

                let heroSize:        CGFloat = compact ? 160 : 220
                let titleSize:       CGFloat = compact ?  30 :  36
                let subtitleSize:    CGFloat = compact ?  16 :  18
                let cardTitleSize:   CGFloat = compact ?  17 :  18
                let cardSubtitleSize:CGFloat = compact ?  14 :  15
                let hPad:            CGFloat = compact ?  16 :  20

                ScrollView(showsIndicators: false) {
                    VStack(spacing: compact ? 14 : 20) {
                        Spacer(minLength: compact ? 0 : 6)

                        // Hero + badge
                        VStack(spacing: compact ? 10 : 16) {
                            if let badge = page.badgeText {
                                badgeView(badge,
                                          compact: compact,
                                          isFirst: isFirst)
                            }
                            heroView(size: heroSize)
                        }
                        .accessibilityHidden(true)

                        // Title
                        Text(page.title)
                            .font(.system(size: titleSize,
                                          weight: .heavy,
                                          design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white,
                                             Color.white.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .padding(.horizontal, hPad)

                        // Subtitle
                        Text(page.subtitle)
                            .font(.system(size: subtitleSize,
                                          weight: .regular,
                                          design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, hPad)

                        // Features
                        VStack(spacing: compact ? 10 : 12) {
                            ForEach(page.features) { f in
                                featureRow(icon: f.icon,
                                           title: f.title,
                                           subtitle: f.subtitle,
                                           titleSize: cardTitleSize,
                                           subtitleSize: cardSubtitleSize)
                            }
                        }
                        .padding(.horizontal, hPad)
                        // Secondary CTA
                        Button(action: onSubscribeTap) {
                            Text("Subscribe now")
                                .font(.system(size: compact ? 16 : 17,
                                              weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, compact ? 10 : 12)
                                .background(Color.white.opacity(0.09))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, hPad)
                    }
                    .padding(.top, compact ? 14 : 24)
                }
            }
        }

        // MARK: - Subviews (локальные)
        private func heroView(size: CGFloat) -> some View {
            switch page.heroKind {
            case .plain:
                return AnyView(bigEmojiBubble(size: size))
            case .charts:
                return AnyView(chartsHero)
            case .reviews:
                return AnyView(reviewsHero)
            case .shield:
                return AnyView(shieldHero)
            }
        }

        private func bigEmojiBubble(size: CGFloat) -> some View {
            ZStack {
                // мягкое свечение вокруг героя
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: 6)

                // внутренний круг с тонкой обводкой
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.88, height: size * 0.88)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                // сам герой: ассет, иначе — эмодзи
                if let name = page.bigIcon {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.72, height: size * 0.72)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                } else {
                    Text(page.bigEmoji)
                        .font(.system(size: size * 0.40))
                }
            }
            .frame(height: size * 1.6)
        }

        private func badgeView(_ text: String,
                               compact: Bool,
                               isFirst: Bool) -> some View {
            let fontSize: CGFloat = isFirst ? (compact ? 18 : 22) : (compact ? 13 : 14)
            let vPad: CGFloat     = isFirst ? (compact ? 7  : 9 ) : (compact ? 5  : 6 )
            let hPad: CGFloat     = isFirst ? (compact ? 12 : 16) : (compact ? 10 : 12)
            let radius: CGFloat   = isFirst ? 14 : 10

            return Text(text.uppercased())
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .tracking(isFirst ? 1.1 : 1.0)
                .padding(.vertical, vPad)
                .padding(.horizontal, hPad)
                .background(Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.25),
                        radius: isFirst ? 10 : 8,
                        y: 4)
        }

        // Один пункт списка фич
        private func featureRow(icon: String,
                                title: String,
                                subtitle: String,
                                titleSize: CGFloat,
                                subtitleSize: CGFloat) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: titleSize))
                    .foregroundColor(.white)
                    .frame(width: titleSize + 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.system(size: subtitleSize))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        // MARK: - Decorative heroes

        // Столбики + «кольца» процентов (для Advanced Analytics)
        private var chartsHero: some View {
            VStack(spacing: 16) {
                HStack(spacing: 18) {
                    bar(height: 50, emoji: "💛")
                    bar(height: 96, emoji: "❤️")
                    bar(height: 70, emoji: "🧡")
                    bar(height: 38, emoji: "💜")
                }
                ring(percent: 58, label: "Subscribers")
                ring(percent: 42, label: "Unsubscribers")
            }
            .padding(.horizontal, 6)
        }

        private func bar(height: CGFloat, emoji: String) -> some View {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 20))
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 26, height: height)
            }
        }

        private func ring(percent: Int, label: String) -> some View {
            HStack(spacing: 10) {
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(Color.white, lineWidth: 6)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)

                Text("\(percent)% \(label)")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)

                Spacer()
            }
        }

        // Отзывы (для Join Our Community)
        private var reviewsHero: some View {
            VStack(spacing: 12) {
                reviewRow(name: "Miranda Smith",
                          text: "Finally, real insights that help me grow!",
                          stars: 5)
                reviewRow(name: "Willie Tanner",
                          text: "Best analytics for Instagram.",
                          stars: 5)
                reviewRow(name: "Capt. Trunk",
                          text: "Exactly what I needed.",
                          stars: 5)
            }
            .padding(.horizontal, 6)
        }

        private func reviewRow(name: String,
                               text: String,
                               stars: Int) -> some View {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 34, height: 34)
                    .overlay(Text("👤").font(.system(size: 18)))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .bold()
                            .foregroundColor(.white)
                        Spacer(minLength: 0)
                        Text(String(repeating: "⭐️",
                                    count: max(0, min(stars, 5))))
                            .font(.system(size: 12))
                    }

                    Text(text)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }

        // Trust/Shield (для Safe with Us)
        private var shieldHero: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                HStack(spacing: 18) {
                    Text("🛡️")
                        .font(.system(size: 64))
                        .shadow(color: .black.opacity(0.25),
                                radius: 6,
                                y: 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Account is Safe with Us")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text("We use secure, policy-compliant methods.")
                            .foregroundColor(.white.opacity(0.9))
                            .font(.footnote)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, 6)
        }
    }
}
