import Foundation
import StoreKit

/// Менеджер покупок на StoreKit 2
/// Интегрирован с Apphud и Adapty для аналитики
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    private init() {
        // Analytics services will be initialized separately if needed
    }

    // MARK: - Продукты

    /// ⚠️ ID должны в точности совпадать с App Store Connect / StoreKit.storekit
    enum ProductID: String, CaseIterable {
        case proWeekly   = "com.jenli.igplanner.pro.weekly"
        case proMonthly  = "com.jenli.igplanner.pro.monthly"   // оставь/удали по желанию
        case proYearly   = "com.jenli.igplanner.pro.yearly"    // оставь/удали по желанию
        case proLifetime = "com.jenli.igplanner.pro.lifetime"  // Non-Consumable (разовая)
        
        // AI Avatar subscriptions
        case aiAvatarWeekly  = "com.jenli.igplanner.ai.avatar.weekly"
        case aiAvatarMonthly = "com.jenli.igplanner.ai.avatar.monthly"
        case aiAvatarYearly  = "com.jenli.igplanner.ai.avatar.yearly"
    }

    // MARK: - Паблишеры для UI

    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    // AI Avatar subscription
    @Published var hasAIAvatarSubscription: Bool = false
    @Published var aiAvatarPlanType: String? = nil  // "weekly" | "monthly" | "yearly"
    
    private var didStartObserver = false
    private var observerTask: Task<Void, Never>?
    
    // Результат покупки для удобной обработки на UI
    enum PurchaseOutcome {
        case purchased
        case cancelled
        case pending
        case failed(Error)
    }

    // MARK: - Публичные методы

    /// Загрузка ассортимента из App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем только те ID, которые объявлены в enum
            let ids = Set(ProductID.allCases.map { $0.rawValue })
            products = try await Product.products(for: ids)
            // После загрузки продуктов сразу проверим текущие права
            await refreshEntitlements()
            // Обновляем статус AI Avatar подписки
            if hasAIAvatarSubscription {
                await refreshAIAvatarSubscriptionStatus()
            }
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    

    // 2) покупка
    func purchase(_ product: Product) async -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Проверяем подпись StoreKit 2
                let transaction: Transaction = try await checkVerified(verification)

                // Обновляем entitlement и завершаем транзакцию
                await updateEntitlements(from: transaction)
                
                // Если это AI Avatar подписка, активируем её на backend
                if isAIAvatarProduct(productID: product.id) {
                    await activateAIAvatarSubscription(productID: product.id, transaction: transaction)
                }
                
                // Track purchase events
                await trackPurchaseEvent(transaction: transaction, product: product)
                
                await transaction.finish()
                return .purchased

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed(
                    NSError(
                        domain: "IAP",
                        code: -999,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown purchase state"]
                    )
                )
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return .failed(error)
        }
    }
    
    /// Восстановление покупок (Restore)
    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // 4) слушатель обновлений транзакций (зови при старте приложения)
    func startTransactionObserver() {
        // не запускаем второй наблюдатель, если уже стартовали
        guard !didStartObserver else { return }
        didStartObserver = true

        observerTask = Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    // класс @MainActor, поэтому к его методам обращаемся через await
                    let transaction: Transaction = try await self.checkVerified(result)
                    await self.updateEntitlements(from: transaction)
                    await transaction.finish()
                } catch {
                    // при желании можно залогировать ошибку
                }
            }
        }
    }
    // MARK: - Helpers

    /// Универсальная проверка подписи StoreKit 2
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw NSError(
                domain: "IAP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"]
            )
        case .verified(let safe):
            return safe
        }
    }

    /// Полное обновление статуса прав (например, при старте/restore)
    private func refreshEntitlements() async {
        var proActive = false
        var aiAvatarActive = false
        var aiAvatarPlan: String? = nil

        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement {
                if isProEntitlement(transaction: t) {
                    proActive = true
                }
                if isAIAvatarEntitlement(transaction: t) {
                    aiAvatarActive = true
                    aiAvatarPlan = getAIAvatarPlanType(from: t.productID)
                }
            }
        }

        await MainActor.run {
            self.isPro = proActive
            self.hasAIAvatarSubscription = aiAvatarActive
            self.aiAvatarPlanType = aiAvatarPlan
        }
        
        // Проверяем статус на backend
        if aiAvatarActive {
            await refreshAIAvatarSubscriptionStatus()
        }
    }

    /// Точечное обновление прав после конкретной транзакции
    private func updateEntitlements(from transaction: Transaction) async {
        let proActive = isProEntitlement(transaction: transaction)
        let aiAvatarActive = isAIAvatarEntitlement(transaction: transaction)
        let aiAvatarPlan = getAIAvatarPlanType(from: transaction.productID)
        
        await MainActor.run {
            self.isPro = proActive || self.isPro
            if aiAvatarActive {
                self.hasAIAvatarSubscription = true
                if let plan = aiAvatarPlan {
                    self.aiAvatarPlanType = plan
                }
            }
        }
        // ↑ если купили lifetime — останемся Pro, даже если подписка позже истечёт
    }

    /// Логика: «Даёт ли эта транзакция статус Pro и она действительна?»
    private func isProEntitlement(transaction: Transaction) -> Bool {
        guard let pid = ProductID(rawValue: transaction.productID) else { return false }

        switch pid {
        case .proWeekly, .proMonthly, .proYearly:
            // Для автообновляемых подписок: активна, если не отозвана и не апгрейднута
            return transaction.revocationDate == nil && !transaction.isUpgraded

        case .proLifetime:
            // Разовая покупка — навсегда даёт Pro
            return true
            
        case .aiAvatarWeekly, .aiAvatarMonthly, .aiAvatarYearly:
            // AI Avatar подписки не дают Pro статус
            return false
        }
    }
    
    /// Логика: «Даёт ли эта транзакция AI Avatar подписку и она действительна?»
    private func isAIAvatarEntitlement(transaction: Transaction) -> Bool {
        guard let pid = ProductID(rawValue: transaction.productID) else { return false }
        
        switch pid {
        case .aiAvatarWeekly, .aiAvatarMonthly, .aiAvatarYearly:
            // Для автообновляемых подписок: активна, если не отозвана и не апгрейднута
            return transaction.revocationDate == nil && !transaction.isUpgraded
            
        default:
            return false
        }
    }
    
    /// Проверяет, является ли product ID AI Avatar подпиской
    private func isAIAvatarProduct(productID: String) -> Bool {
        guard let pid = ProductID(rawValue: productID) else { return false }
        switch pid {
        case .aiAvatarWeekly, .aiAvatarMonthly, .aiAvatarYearly:
            return true
        default:
            return false
        }
    }
    
    /// Получает тип плана AI Avatar из product ID
    private func getAIAvatarPlanType(from productID: String) -> String? {
        guard let pid = ProductID(rawValue: productID) else { return nil }
        switch pid {
        case .aiAvatarWeekly: return "weekly"
        case .aiAvatarMonthly: return "monthly"
        case .aiAvatarYearly: return "yearly"
        default: return nil
        }
    }
    
    // MARK: - AI Avatar Subscription Management
    
    /// Активирует AI Avatar подписку на backend после успешной покупки
    private func activateAIAvatarSubscription(productID: String, transaction: Transaction) async {
        guard let planType = getAIAvatarPlanType(from: productID) else { return }
        
        // Вычисляем дату истечения на основе типа плана
        let expiresAt: Date
        switch planType {
        case "weekly":
            expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        case "monthly":
            expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case "yearly":
            expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        default:
            return
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiresAtString = formatter.string(from: expiresAt)
        
        do {
            _ = try await AIAvatarSubscriptionAPI.activateSubscription(
                planType: planType,
                userID: nil,  // TODO: использовать реальный user_id если будет авторизация
                expiresAt: expiresAtString
            )
            print("✅ AI Avatar subscription activated on backend: \(planType)")
        } catch {
            print("⚠️ Failed to activate AI Avatar subscription on backend: \(error)")
            // Не блокируем покупку, если backend недоступен
        }
    }
    
    /// Обновляет статус AI Avatar подписки с backend
    private func refreshAIAvatarSubscriptionStatus() async {
        do {
            let status = try await AIAvatarSubscriptionAPI.getSubscriptionStatus(userID: nil)
            await MainActor.run {
                self.hasAIAvatarSubscription = status.is_active
                self.aiAvatarPlanType = status.plan_type
            }
        } catch {
            print("⚠️ Failed to refresh AI Avatar subscription status: \(error)")
        }
    }
    
    /// Получает тип плана AI Avatar подписки
    func getAIAvatarPlanType() -> String? {
        return aiAvatarPlanType
    }
    
    // MARK: - Analytics Integration
    
    /// Track purchase event in Apphud and Adapty
    private func trackPurchaseEvent(transaction: Transaction, product: Product) async {
        // Apphud tracking
        Task {
            do {
                let receipt = await getReceiptData()
                try await ApphudManager.shared.trackSubscriptionEvent(
                    event: .subscriptionStarted,
                    productId: product.id,
                    transactionId: String(transaction.id),
                    receipt: receipt
                )
            } catch {
                print("⚠️ Apphud tracking failed: \(error)")
            }
        }
        
        // Adapty tracking
        Task {
            do {
                // Get currency code from locale (product doesn't expose currency directly)
                let currencyCode: String
                if #available(iOS 16.0, *) {
                    if let currency = Locale.current.currency {
                        currencyCode = currency.identifier
                    } else {
                        currencyCode = "USD"
                    }
                } else {
                    if let code = Locale.current.currencyCode {
                        currencyCode = code
                    } else {
                        currencyCode = "USD"
                    }
                }
                
                try await AdaptyManager.shared.trackEvent(
                    name: "purchase_completed",
                    params: [
                        "product_id": product.id,
                        "transaction_id": String(transaction.id),
                        "price": product.price.description,
                        "currency": currencyCode
                    ]
                )
            } catch {
                print("⚠️ Adapty tracking failed: \(error)")
            }
        }
    }
    
    /// Get App Store receipt data
    /// Note: appStoreReceiptURL is deprecated in iOS 18+, using Transaction API instead
    private func getReceiptData() async -> String? {
        if #available(iOS 18.0, *) {
            // iOS 18+: Use AppTransaction or Transaction.currentEntitlements
            // Receipt data is not directly available, return nil
            // Analytics services can use transaction IDs instead
            return nil
        } else {
            // iOS < 18: Use deprecated but still working API
            #if !os(visionOS)
            guard let receiptURL = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: receiptURL) else {
                return nil
            }
            return receiptData.base64EncodedString()
            #else
            return nil
            #endif
        }
    }
}
