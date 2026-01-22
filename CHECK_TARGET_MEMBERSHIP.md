# ✅ Проверка Target Membership

## Проблема: Файлы с "?" в Xcode

Если файлы показывают "?" в Project Navigator, это значит они **не добавлены в Target**.

---

## 🔧 Как исправить

### Для каждого файла с "?":

1. **Выбери файл** в Project Navigator (например, `LocalizationManager.swift`)
2. Открой **File Inspector** (правая панель, или `Cmd + Option + 1`)
3. Прокрути до секции **"Target Membership"**
4. ✅ **Поставь галочку** на **"IG Planner"**
5. Повтори для всех файлов с "?"

---

## 📋 Файлы, которые нужно проверить:

### Swift файлы:
- ✅ `LocalizationManager.swift`
- ✅ `LanguagePickerView.swift`
- ✅ `AppleSearchAdsManager.swift`
- ✅ `ApphudManager.swift`
- ✅ `AdaptyManager.swift`
- ✅ `AIGenerationAPI.swift`
- ✅ `IGStoriesAPI.swift`

### .lproj папки:
- ✅ Все папки локализации (en.lproj, es.lproj, ru.lproj и т.д.)
- ✅ Внутри каждой папки должен быть `Localizable.strings`

---

## ⚠️ Важно для .lproj папок:

1. Выбери папку `.lproj` (например, `en.lproj`)
2. File Inspector → **Target Membership**
3. ✅ Галочка на **"IG Planner"**
4. ✅ Убедись, что тип папки: **"Folder Reference"** (не "Group")

---

## 🔍 Быстрая проверка:

1. **Build** (`Cmd + B`)
2. Если ошибка: **"Cannot find 'X' in scope"**
   → Файл не в Target
3. Выбери файл → File Inspector → Target Membership → ✅ IG Planner

---

## ✅ После исправления:

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Build**: `Cmd + B`
3. Должно быть **0 ошибок**
