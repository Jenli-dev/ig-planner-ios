import SwiftUI
import StoreKit

// MARK: - Local theme for Paywall (в цветах онбординга)
private struct PWTheme {
    static let pill = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.33, blue: 0.55),
            Color(red: 0.92, green: 0.40, blue: 0.92),
            Color(red: 0.95, green: 0.60, blue: 0.25)
        ],
        startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - Plan Enum (UI-модель)
enum Plan: CaseIterable {
    case weekly, monthly, yearly, lifetime

    var title: String {
        switch self {
        case .weekly:   return "Popular"
        case .monthly:  return "Monthly"
        case .yearly:   return "Best deal"
        case .lifetime: return "Lifetime deal"
        }
    }

    var subtitle: String? {
        switch self {
        case .weekly:   return "Best to try features"
        case .monthly:  return "Save 20%"
        case .yearly:   return "Save 50%"
        case .lifetime: return nil
        }
    }

    /// Короткая цена по умолчанию, пока не подтянулись StoreKit-продукты
    var priceShort: String {
        switch self {
        case .weekly:   return "€7 /week"
        case .monthly:  return "€14 /month"
        case .yearly:   return "€44 /year"
        case .lifetime: return "€69.99 /one time"
        }
    }

    var ctaTitle: String {
        switch self {
        case .weekly:   return "Subscribe Weekly"
        case .monthly:  return "Subscribe Monthly"
        case .yearly:   return "Subscribe Yearly"
        case .lifetime: return "Unlock Lifetime"
        }
    }

    /// показываем бейдж про триал только на weekly
    var hasTrial: Bool { self == .weekly }
    var trialDays: Int { self == .weekly ? 3 : 0 }

    /// Привязка планов к productID из App Store Connect (ЗАМЕНИ идентификаторы)
    var productID: String {
        switch self {
        case .weekly:   return "com.jenli.igplanner.pro.weekly"
        case .monthly:  return "com.jenli.igplanner.pro.monthly"
        case .yearly:   return "com.jenli.igplanner.pro.yearly"
        case .lifetime: return "com.jenli.igplanner.pro.lifetime"
        }
    }
}

// MARK: - Paywall (режимы: первичный / вторичный)
struct PaywallView: View {
    enum Mode { case primary, secondary }

    // колбэки
    var onClose: (() -> Void)? = nil
    var onSubscribed: (() -> Void)? = nil
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchases: PurchaseManager

    // StoreKit
    @State private var productsByID: [String: Product] = [:]
    @State private var isProcessing = false
    @State private var errorText: String?

    // UI
    @State private var showAllPlans = false
    @State private var selectedPlan: Plan = .weekly

    // быстрый доступ к SK Product
    private func product(for plan: Plan) -> Product? { productsByID[plan.productID] }

    // по умолчанию – primary
    init(mode: Mode = .primary,
         onClose: (() -> Void)? = nil,
         onSubscribed: (() -> Void)? = nil) {
        self.mode = mode
        self.onClose = onClose
        self.onSubscribed = onSubscribed
    }

    var body: some View {
        ZStack {

            // фоновые эмодзи поверх фона, но под контентом
            EmojiTopBand()
                .allowsHitTesting(false)
                .zIndex(0)

            ScrollView {
                VStack(spacing: 12) {
                    // Close
                    HStack {
                        Button { (onClose ?? { dismiss() })() } label: {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.leading, 20)
                        .padding(.top, 10)
                        Spacer()
                    }

                    header
                    bullets

                    // Верхний прайс-бейдж и большая CTA — только в primary,
                    // и только когда список планов не раскрыт
                    if mode == .primary && !showAllPlans {
                        priceBadge
                        ctaButton
                    }

                    // Тогглер «Other plans…» — только в primary
                    if mode == .primary {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                showAllPlans.toggle()
                            }
                        } label: {
                            Text(showAllPlans ? "Hide other plans" : "Other plans…")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.top, 4)
                    }

                    // Список планов: всегда во вторичном пейволе,
                    // либо по кнопке во первичном
                    if mode == .secondary || showAllPlans {
                        plansList
                    }

                    footerLinks
                }
                .padding(.bottom, 16)
            }
            .zIndex(1)
        }
        .brandBackground()                 // ← единый бренд-фон (из AppGradient.brand)
        .pwLoadingOverlay(isProcessing)
        .task {
            await purchases.loadProducts()
            purchases.startTransactionObserver()
            await loadProductsIfNeeded()
        }
        .alert("Error", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK") { errorText = nil }
        } message: { Text(errorText ?? "") }
        .interactiveDismissDisabled(isProcessing)
        .onAppear {
            // во втором пейволе сразу показываем список
            if mode == .secondary { showAllPlans = true }
        }
    }
}
        
// MARK: - UI building blocks
private extension PaywallView {
    var header: some View {
        VStack(spacing: 4) {
            HeartBadgeView()
                .padding(.bottom, 2)

            Text("Enhance Your Profile")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("with Powerful Tools")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }
    
    var bullets: some View {
        VStack(alignment: .leading, spacing: 10) {
            bullet("😮‍💨  See who doesn't follow you back")
            bullet("👻  Identify ghost followers")
            bullet("📈  Explore story & post analytics")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    var priceBadge: some View {
        let weeklyPrice = product(for: .weekly)?.displayPrice ?? Plan.weekly.priceShort
        return Text("3 days free • then \(weeklyPrice)")
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
            .foregroundColor(.white)
    }

    var ctaButton: some View {
        Button {
            selectedPlan = .weekly
            Task { await subscribe() }
        } label: {
            Text("Try 3 days free")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PWTheme.pill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .foregroundColor(.white)
        }
        .disabled(isProcessing)
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    var plansList: some View {
        VStack(spacing: 8) {
            planRow(.weekly)
            planRow(.monthly)
            planRow(.yearly)
            planRow(.lifetime)

            Button {
                Task { await subscribe() }
            } label: {
                Text(selectedPlan.hasTrial ? "Try \(selectedPlan.trialDays) days free"
                                           : selectedPlan.ctaTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PWTheme.pill))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
                    .foregroundColor(.white)
            }
            .disabled(isProcessing)
            .padding(.top, 4)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }

    var footerLinks: some View {
        HStack(spacing: 14) {
            Link("Terms of Use", destination: URL(string: "https://jenli.net/Terms-of-Use")!)
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 11))

            Divider().frame(height: 10).background(Color.white.opacity(0.25))

            Link("Privacy Policy", destination: URL(string: "https://jenli.net/privacy")!)
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 11))

            Divider().frame(height: 10).background(Color.white.opacity(0.25))

            Button("Restore") {
                Task { await purchases.restore() }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.95))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func planRow(_ plan: Plan) -> some View {
        let isSelected = selectedPlan == plan
        let priceText  = product(for: plan)?.displayPrice ?? plan.priceShort

        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                Spacer()
                Text(priceText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.18),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.white.opacity(0.25))
                .frame(width: 6, height: 6)
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
    }
} // ← ВАЖНО: закрываем extension ровно здесь
// MARK: - Большое сердце с «1»
private struct HeartBadgeView: View {
    var body: some View {
        ZStack {
            // Внешнее свечение
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 90, height: 90)
                .blur(radius: 5)

            // Основной круг
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 78, height: 78)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                )

            // Бейдж «1» на краю круга
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().fill(Color.red.opacity(0.95))
                        Text("1")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                    .offset(x: 6, y: -6)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 78, height: 78)
        }
    }
}

// MARK: - Emoji cloud across the top
private struct EmojiTopBand: View {
    private let emojis = ["⭐️","❤️","✨","👍","👏","💬","😍","🔥","🥳","🤩","💎","🌟","🙌","💖","🎉","⭐️","❤️","✨","👍","👏","💬","😍","🔥","🤩","🎉"]

    private struct Item: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: Double
        let opacity: Double
    }

    @State private var items: [Item] = []
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            // верхняя зона: от самого верха (включая safe area) до «чуть ниже» — примерно до сердца
            let topInset = geo.safeAreaInsets.top
            let bandHeight = min(topInset + 120, geo.size.height * 0.28) // ← ключевая высота

            ZStack {
                ForEach(items) { it in
                    Text(it.emoji)
                        .font(.system(size: it.size))
                        .opacity(it.opacity)              // 0.25…0.40 — фоновые
                        .blur(radius: 0.3)
                        .position(
                            x: it.x,
                            y: it.y + 5 * sin(t + CGFloat(it.phase) * .pi * 2)
                        )
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: bandHeight)
            .ignoresSafeArea(edges: .top)    // тянем под статус-бар/«бровь»
            .mask(                            // мягкое затухание снизу, чтобы «вплавить» в фон
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white, location: 0.82),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onAppear {
                guard items.isEmpty else { return }

                let w = max(geo.size.width, 320)          // ширина гарантированно не слишком мала
                let topInset = geo.safeAreaInsets.top
                let bandHeight = max(topInset + 140, 60)  // страховка на всякий случай

                let count = max(28, Int(w / 12))          // плотность

                var gen: [Item] = []
                for i in 0..<count {
                    let e = emojis[i % emojis.count]

                    // безопасные границы
                    let maxX = max(9, w - 8)
                    let maxY = max(1, bandHeight - 12)

                    let x = CGFloat.random(in: 8...maxX)
                    let y = CGFloat.random(in: 0...maxY)

                    let size    = CGFloat.random(in: 18...28)
                    let phase   = Double.random(in: 0...1)
                    let opacity = Double.random(in: 0.25...0.40)

                    gen.append(.init(emoji: e, x: x, y: y, size: size, phase: phase, opacity: opacity))
                }
                items = gen
                t = 1
            }
        }
    }
}

// MARK: - StoreKit glue
private extension PaywallView {

    func loadProductsIfNeeded() async {
        if !productsByID.isEmpty { return }
        let ids = Set(Plan.allCases.map { $0.productID })
        do {
            let products = try await Product.products(for: Array(ids))
            var map: [String: Product] = [:]
            for p in products { map[p.id] = p }
            await MainActor.run { productsByID = map }
        } catch {
            await MainActor.run {
                errorText = "Failed to load products: \(error.localizedDescription)"
            }
        }
    }

    /// Покупка выбранного плана (исправленная версия без await в defer)
    func subscribe() async {
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }

        if product(for: selectedPlan) == nil {
            await loadProductsIfNeeded()
        }
        guard let product = product(for: selectedPlan) else {
            await MainActor.run {
                errorText = "Products not ready yet. Please try again in a moment."
            }
            return
        }

        await MainActor.run {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let outcome = await purchases.purchase(product)
        await MainActor.run {
            switch outcome {
            case .purchased:
                onSubscribed?()
                (onClose ?? { dismiss() })()
            case .pending, .cancelled:
                break
            case .failed(let err):
                errorText = err.localizedDescription
            }
        }
    }
}
// MARK: - Small helpers / modifiers
private extension View {
/// Простая затемняющая подложка с лоадером
func pwLoadingOverlay(_ isLoading: Bool) -> some View {
    ZStack {
        self
        if isLoading {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)
        }
    }
    .animation(.easeInOut(duration: 0.15), value: isLoading)
}
}

// MARK: - Wrap PaywallView with helpers
struct PaywallContainer: View {
    let onClose: (() -> Void)?
    let onSubscribed: (() -> Void)?
    let mode: PaywallView.Mode   // ← добавили режим (primary / secondary)

    init(mode: PaywallView.Mode = .secondary,
         onClose: (() -> Void)? = nil,
         onSubscribed: (() -> Void)? = nil) {
        self.mode = mode
        self.onClose = onClose
        self.onSubscribed = onSubscribed
    }

    @EnvironmentObject var purchases: PurchaseManager
    
    var body: some View {
        PaywallView(mode: mode, onClose: onClose, onSubscribed: onSubscribed)
            .onChange(of: purchases.isPro) { oldValue, newValue in
                if mode == .secondary && newValue && !oldValue {
                    onSubscribed?()
                    onClose?()
                }
            }
    }
}
// MARK: - Preview
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView(mode: .primary)
                .pwLoadingOverlay(false)
                .previewDisplayName("Primary paywall")

            PaywallView(mode: .secondary)
                .previewDisplayName("Secondary (plans open)")

            PaywallView(mode: .primary)
                .pwLoadingOverlay(true)
                .previewDisplayName("Processing")
        }
        .preferredColorScheme(.dark)
    }
}
