import SwiftUI
import StoreKit

// MARK: - AI Avatar Plan Enum

enum AIAvatarPlan: CaseIterable {
    case weekly, monthly, yearly
    
    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var productID: String {
        switch self {
        case .weekly: return "com.jenli.igplanner.ai.avatar.weekly"
        case .monthly: return "com.jenli.igplanner.ai.avatar.monthly"
        case .yearly: return "com.jenli.igplanner.ai.avatar.yearly"
        }
    }
    
    var planType: String {
        switch self {
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        }
    }
    
    var creditsInfo: String {
        switch self {
        case .weekly: return "20 credits/week"
        case .monthly: return "80 credits/month"
        case .yearly: return "1200 credits/year"
        }
    }
    
    var isBestValue: Bool {
        self == .yearly
    }
}

// MARK: - AI Avatar Paywall View

struct AIAvatarPaywallView: View {
    var onClose: (() -> Void)? = nil
    var onSubscribed: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchases: PurchaseManager
    
    @State private var productsByID: [String: Product] = [:]
    @State private var isProcessing = false
    @State private var errorText: String?
    @State private var selectedPlan: AIAvatarPlan = .yearly
    
    private func product(for plan: AIAvatarPlan) -> Product? {
        productsByID[plan.productID]
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            AppGradient.brand
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: {
                            onClose?()
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.3), in: Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    
                    // Avatar examples
                    avatarExamplesSection
                        .padding(.top, 20)
                    
                    // Title
                    Text("Extra Creativity on Top of Your Main Subscription")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                    
                    // Features list
                    featuresList
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                    
                    // Subscription plans
                    subscriptionPlans
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                    
                    // Continue button
                    continueButton
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    
                    // Footer
                    footer
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadProducts()
        }
    }
    
    // MARK: - Avatar Examples Section
    
    private var avatarExamplesSection: some View {
        HStack(spacing: -20) {
            // Three overlapping avatar images
            ForEach(0..<3) { index in
                AsyncImage(url: URL(string: avatarExampleURLs[index])) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 160)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    case .failure:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 160)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 160)
                    }
                }
                .overlay(
                    // Sparkle icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                        .offset(x: 8, y: -8)
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var avatarExampleURLs: [String] {
        [
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&h=400&fit=crop&crop=faces",
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=400&fit=crop&crop=faces"
        ]
    }
    
    // MARK: - Features List
    
    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(emoji: "🔥", text: "Multiple AI Systems")
            FeatureRow(emoji: "🤩", text: "Text-to-Avatar Generation")
            FeatureRow(emoji: "🎁", text: "Avatar Library Access")
            FeatureRow(emoji: "🔥", text: "Monthly Avatar Replacement")
        }
    }
    
    // MARK: - Subscription Plans
    
    private var subscriptionPlans: some View {
        VStack(spacing: 16) {
            ForEach(AIAvatarPlan.allCases, id: \.self) { plan in
                SubscriptionPlanRow(
                    plan: plan,
                    product: product(for: plan),
                    isSelected: selectedPlan == plan,
                    onSelect: {
                        selectedPlan = plan
                    }
                )
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            Task {
                await purchaseSelectedPlan()
            }
        } label: {
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isProcessing || product(for: selectedPlan) == nil)
        .opacity((isProcessing || product(for: selectedPlan) == nil) ? 0.6 : 1.0)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button("Terms of Use") {
                // TODO: Open terms
            }
            Text("|")
                .foregroundColor(.white.opacity(0.5))
            Button("Privacy Policy") {
                // TODO: Open privacy
            }
            Text("|")
                .foregroundColor(.white.opacity(0.5))
            Button("Restore") {
                Task {
                    await purchases.restore()
                }
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.8))
    }
    
    // MARK: - Methods
    
    private func loadProducts() async {
        // Load AI Avatar products
        let aiAvatarProductIDs = Set(AIAvatarPlan.allCases.map { $0.productID })
        do {
            let products = try await Product.products(for: aiAvatarProductIDs)
            await MainActor.run {
                for product in products {
                    productsByID[product.id] = product
                }
            }
        } catch {
            print("⚠️ Failed to load AI Avatar products: \(error)")
        }
    }
    
    private func purchaseSelectedPlan() async {
        guard let product = product(for: selectedPlan) else {
            errorText = "Product not available"
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let outcome = await purchases.purchase(product)
        
        switch outcome {
        case .purchased:
            onSubscribed?()
            dismiss()
        case .cancelled:
            break
        case .pending:
            errorText = "Purchase is pending approval"
        case .failed(let error):
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let emoji: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 24))
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
    }
}

// MARK: - Subscription Plan Row

struct SubscriptionPlanRow: View {
    let plan: AIAvatarPlan
    let product: Product?
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if plan.isBestValue {
                            Text("Best Value")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow, in: Capsule())
                        }
                    }
                    
                    if let product = product {
                        Text(formatPrice(product: product))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text(plan.creditsInfo)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Checkmark or circle
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatPrice(product: Product) -> String {
        // Use product.displayPrice which is already formatted
        let priceString = product.displayPrice
        
        switch plan {
        case .weekly:
            return "\(priceString)/week"
        case .monthly:
            return "\(priceString)/month"
        case .yearly:
            return "\(priceString)/year"
        }
    }
}

// MARK: - Preview

#Preview {
    AIAvatarPaywallView()
        .environmentObject(PurchaseManager.shared)
}
