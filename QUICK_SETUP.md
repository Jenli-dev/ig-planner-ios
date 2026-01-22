# 🚀 Быстрая настройка аналитики

## Что нужно сделать

### 1️⃣ Apple Search Ads API

**Где получить:**
1. App Store Connect → Users and Access → Keys
2. Создать новый ключ → Скачать .p8 файл
3. Записать Key ID и Issuer ID

**В Render добавить:**
```
APPLE_SEARCH_ADS_KEY_ID=ABC123XYZ
APPLE_SEARCH_ADS_ISSUER_ID=12345678-1234-1234-1234-123456789012
APPLE_SEARCH_ADS_PRIVATE_KEY=<base64_encoded_p8_content>
```

**Конвертация .p8 в base64:**
```bash
cat AuthKey_XXXXXXXXXX.p8 | base64 | pbcopy
```

---

### 2️⃣ Apphud

**Где получить:**
1. https://apphud.com/ → Sign up
2. Dashboard → Settings → API Keys
3. Скопировать API Key

**В Render добавить:**
```
APPHUD_API_KEY=apphud_xxxxxxxxxxxxx
```

**Что дает:**
- 📊 Аналитика подписок (MRR, ARPU, Churn)
- 📈 Когорты и воронки
- 🔄 Win-back кампании
- 💰 Refund management

---

### 3️⃣ Adapty

**Где получить:**
1. https://adapty.io/ → Sign up
2. Dashboard → Settings → API Keys
3. Скопировать API Key

**В Render добавить:**
```
ADAPTY_API_KEY=public_live_xxxxxxxxxxxxx
```

**Что дает:**
- 🧪 A/B тестирование paywalls
- 🎨 Paywall builder (Figma → код)
- 📱 Онбординги и флоу
- 📊 Продуктовые метрики

---

## 📱 В Xcode

### Добавить фреймворки:
1. Project → Target → General → Frameworks
2. Добавить:
   - `AdSupport.framework`
   - `AppTrackingTransparency.framework`

### Добавить в Info.plist:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use this to measure the effectiveness of our advertising campaigns and improve your experience.</string>
```

### Добавить SDK (опционально):

**Adapty SDK:**
```
File → Add Package Dependencies
URL: https://github.com/adapty/AdaptySDK-iOS
Version: 2.7.0+
```

**Apphud SDK (опционально):**
```
File → Add Package Dependencies
URL: https://github.com/apphud/ApphudSDK-Swift
```

---

## ✅ Готово!

После настройки:
- ✅ Apple Search Ads будет автоматически отслеживать установки
- ✅ Apphud будет собирать аналитику подписок
- ✅ Adapty будет управлять paywalls и A/B тестами
- ✅ Все события покупок будут автоматически отправляться

---

## 🔍 Проверка

После деплоя проверь:
1. Логи в Render (должны быть успешные запросы)
2. Apphud Dashboard → Events (должны появляться события)
3. Adapty Dashboard → Paywalls (должны быть доступны)

---

## 📚 Документация

- **Apple Search Ads**: https://developer.apple.com/app-store-connect/api/
- **Apphud**: https://docs.apphud.com/
- **Adapty**: https://docs.adapty.io/
