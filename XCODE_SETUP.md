# 🔧 Настройка Xcode проекта

## Проблема: Файлы не видны в Xcode

Все файлы созданы, но их нужно **добавить в Xcode проект** вручную.

---

## ✅ Шаг 1: Добавить файлы в проект

### В Xcode:

1. **Правой кнопкой** на папку `IG Planner` в Project Navigator
2. Выбрать **"Add Files to 'IG Planner'..."**
3. Выбрать следующие файлы:
   - `LocalizationManager.swift`
   - `LanguagePickerView.swift`
   - `AppleSearchAdsManager.swift`
   - `ApphudManager.swift`
   - `AdaptyManager.swift`
4. ✅ Убедиться, что стоит галочка **"Copy items if needed"** (если файлы не в папке проекта)
5. ✅ Выбрать **Target: "IG Planner"**
6. Нажать **"Add"**

---

## ✅ Шаг 2: Добавить .lproj папки

1. **Правой кнопкой** на папку `IG Planner` в Project Navigator
2. Выбрать **"Add Files to 'IG Planner'..."**
3. Выбрать все папки `.lproj`:
   - `en.lproj`
   - `es.lproj`
   - `ru.lproj`
   - `uk.lproj`
   - `pt.lproj`
   - `zh-Hans.lproj`
   - `zh-Hant.lproj`
   - `zh-CN.lproj`
   - `hi.lproj`
   - `nl.lproj`
   - `de.lproj`
   - `fr.lproj`
   - `it.lproj`
   - `id.lproj`
   - `ms.lproj`
   - `th.lproj`
   - `vi.lproj`
4. ✅ Выбрать **"Create folder references"** (НЕ "Create groups")
5. ✅ Выбрать **Target: "IG Planner"**
6. Нажать **"Add"**

---

## ✅ Шаг 3: Добавить фреймворки

1. Project → Target **"IG Planner"** → **General** → **Frameworks, Libraries, and Embedded Content**
2. Нажать **"+"**
3. Добавить:
   - `AdSupport.framework`
   - `AppTrackingTransparency.framework`
4. Убедиться, что стоит **"Do Not Embed"**

---

## ✅ Шаг 4: Добавить в Info.plist

1. Открыть `IG-Planner-Info.plist`
2. Добавить ключ:
   ```xml
   <key>NSUserTrackingUsageDescription</key>
   <string>We use this to measure the effectiveness of our advertising campaigns and improve your experience.</string>
   ```

Или через Xcode UI:
- **Info** tab → **Custom iOS Target Properties**
- Добавить: `Privacy - Tracking Usage Description`
- Значение: `We use this to measure the effectiveness of our advertising campaigns and improve your experience.`

---

## ✅ Шаг 5: Проверить Build Settings

1. Project → Target → **Build Settings**
2. Найти **"Swift Compiler - Language"**
3. Убедиться, что **Swift Language Version** = **Swift 5** или выше

---

## 🔍 Проверка

После добавления файлов:
1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Build**: `Cmd + B`
3. Все ошибки должны исчезнуть

---

## ⚠️ Если ошибки остались

### Ошибка: "Cannot find 'X' in scope"

**Решение:** Файл не добавлен в Target. Проверь:
- Project Navigator → выбери файл
- File Inspector (правая панель) → **Target Membership**
- ✅ Должна быть галочка на **"IG Planner"**

### Ошибка: "Value of type 'String' has no member 'localized'"

**Решение:** `LocalizationManager.swift` не добавлен в проект или не в Target.

### Ошибка: "Cannot find 'ApphudManager' in scope"

**Решение:** `ApphudManager.swift` не добавлен в проект.

---

## 📝 Быстрая проверка

Открой **Project Navigator** и проверь, что видишь:
- ✅ `LocalizationManager.swift`
- ✅ `LanguagePickerView.swift`
- ✅ `AppleSearchAdsManager.swift`
- ✅ `ApphudManager.swift`
- ✅ `AdaptyManager.swift`
- ✅ Папки `.lproj` с `Localizable.strings` внутри

Если чего-то нет → добавь по инструкции выше.
