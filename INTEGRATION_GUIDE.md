# Интеграция Apple Search Ads, Apphud и Adapty

## 📋 Что нужно для каждой интеграции

### 1. Apple Search Ads API

**Требования:**
1. **App Store Connect API Key** (.p8 файл)
   - Зайти в App Store Connect → Users and Access → Keys
   - Создать новый ключ с ролью "Admin" или "App Manager"
   - Скачать .p8 файл (только один раз!)
   - Записать Key ID и Issuer ID

2. **Настройка в Xcode:**
   - Добавить `AdSupport.framework`
   - Добавить `AppTrackingTransparency.framework`
   - В `Info.plist` добавить:
     ```xml
     <key>NSUserTrackingUsageDescription</key>
     <string>We use this to measure the effectiveness of our advertising campaigns and improve your experience.</string>
     ```

3. **Переменные окружения (Render/Backend):**
   ```
   APPLE_SEARCH_ADS_KEY_ID=your_key_id
   APPLE_SEARCH_ADS_ISSUER_ID=your_issuer_id
   APPLE_SEARCH_ADS_PRIVATE_KEY=base64_encoded_p8_content
   ```

**Как получить .p8 в base64:**
```bash
cat AuthKey_XXXXXXXXXX.p8 | base64
```

**Документация:**
- https://developer.apple.com/app-store-connect/api/
- https://developer.apple.com/documentation/appstoreconnectapi

---

### 2. Apphud

**Требования:**
1. **Регистрация:**
   - Зайти на https://apphud.com/
   - Создать аккаунт
   - Создать новое приложение
   - Получить API Key из Dashboard → Settings → API Keys

2. **SDK (опционально):**
   - SPM: `https://github.com/apphud/ApphudSDK-Swift`
   - Или использовать REST API (уже реализовано)

3. **Переменные окружения:**
   ```
   APPHUD_API_KEY=your_api_key
   ```

**Документация:**
- https://docs.apphud.com/
- https://apphud.com/docs/ios

**Возможности:**
- ✅ Аналитика подписок (MRR, ARPU, Churn)
- ✅ Когорты и воронки
- ✅ Интеграции с MMPs
- ✅ Win-back кампании
- ✅ Refund management

---

### 3. Adapty

**Требования:**
1. **Регистрация:**
   - Зайти на https://adapty.io/
   - Создать аккаунт
   - Создать новое приложение
   - Получить API Key из Dashboard → Settings → API Keys

2. **SDK (рекомендуется):**
   - SPM: `https://github.com/adapty/AdaptySDK-iOS`
   - Версия: 2.7.0+

3. **Переменные окружения:**
   ```
   ADAPTY_API_KEY=your_api_key
   ```

**Документация:**
- https://docs.adapty.io/
- https://docs.adapty.io/docs/ios-sdk

**Возможности:**
- ✅ A/B тестирование paywalls
- ✅ Онбординги и флоу
- ✅ Продуктовые метрики
- ✅ Revenue analytics
- ✅ Paywall builder (Figma → код)

---

## 🚀 Быстрый старт

### Шаг 1: Настройка Apple Search Ads

1. Получить .p8 ключ из App Store Connect
2. Конвертировать в base64
3. Добавить переменные в Render:
   ```
   APPLE_SEARCH_ADS_KEY_ID=...
   APPLE_SEARCH_ADS_ISSUER_ID=...
   APPLE_SEARCH_ADS_PRIVATE_KEY=...
   ```

### Шаг 2: Настройка Apphud

1. Зарегистрироваться на apphud.com
2. Создать приложение
3. Получить API Key
4. Добавить в Render:
   ```
   APPHUD_API_KEY=...
   ```

### Шаг 3: Настройка Adapty

1. Зарегистрироваться на adapty.io
2. Создать приложение
3. Получить API Key
4. Добавить в Render:
   ```
   ADAPTY_API_KEY=...
   ```

### Шаг 4: Добавить SDK в Xcode

**Apphud (опционально):**
```
File → Add Package Dependencies
URL: https://github.com/apphud/ApphudSDK-Swift
```

**Adapty (рекомендуется):**
```
File → Add Package Dependencies
URL: https://github.com/adapty/AdaptySDK-iOS
Version: 2.7.0+
```

### Шаг 5: Инициализация в приложении

В `IGPlannerApp.swift` или `RootView.swift`:

```swift
@main
struct IGPlannerApp: App {
    @StateObject private var localization = LocalizationManager.shared
    
    init() {
        // Initialize analytics
        Task {
            // Request ATT permission for Search Ads
            _ = await AppleSearchAdsManager.shared.requestTrackingPermission()
            await AppleSearchAdsManager.shared.requestAttributionToken()
            
            // Initialize Apphud
            ApphudManager.shared.initialize()
            
            // Initialize Adapty
            try? await AdaptyManager.shared.initialize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environmentObject(localization)
        }
    }
}
```

---

## 📊 Использование

### Apple Search Ads

```swift
// В приложении после получения ATT разрешения
await AppleSearchAdsManager.shared.requestAttributionToken()
await AppleSearchAdsManager.shared.sendAttributionToBackend()
```

### Apphud

```swift
// Автоматически через PurchaseManager
// Или вручную:
try await ApphudManager.shared.trackSubscriptionEvent(
    event: .subscriptionStarted,
    productId: "com.jenli.igplanner.pro.monthly",
    transactionId: "123456"
)
```

### Adapty

```swift
// Получить paywall для A/B теста
let paywall = await AdaptyManager.shared.getPaywall(placementId: "main")

// Отследить событие
try await AdaptyManager.shared.trackEvent(
    name: "paywall_viewed",
    params: ["placement": "main"]
)
```

---

## 🔗 Полезные ссылки

- **Apple Search Ads API**: https://developer.apple.com/app-store-connect/api/
- **Apphud Docs**: https://docs.apphud.com/
- **Adapty Docs**: https://docs.adapty.io/
- **Apphud Dashboard**: https://app.apphud.com/
- **Adapty Dashboard**: https://app.adapty.io/

---

## ⚠️ Важные замечания

1. **Apple Search Ads**: Требует ATT (App Tracking Transparency) разрешение
2. **Apphud**: Можно использовать REST API без SDK
3. **Adapty**: Рекомендуется использовать SDK для A/B тестов paywalls
4. **Безопасность**: Никогда не коммитьте API ключи в git. Используйте переменные окружения.
