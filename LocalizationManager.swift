import Foundation
import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case portuguese = "pt"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case mandarin = "zh-CN"
    case hindi = "hi"
    case dutch = "nl"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case indonesian = "id"
    case malay = "ms"
    case thai = "th"
    case vietnamese = "vi"
    case russian = "ru"
    case ukrainian = "uk"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .mandarin: return "普通话"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .thai: return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .mandarin: return "普通话"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .thai: return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        }
    }
}

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    nonisolated(unsafe) static let shared: LocalizationManager = LocalizationManager()
    
    @MainActor @Published var currentLanguage: AppLanguage = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            updateBundle()
        }
    }
    
    // Bundle is thread-safe, so we can mark it as nonisolated(unsafe)
    nonisolated(unsafe) private var bundle: Bundle?
    private let bundleLock = NSLock() // Thread-safe access to bundle
    
    nonisolated private init() {
        // Load saved language or use system language
        let initialLanguage: AppLanguage
        if let savedLang = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: savedLang) {
            initialLanguage = lang
        } else {
            // Auto-detect from system
            initialLanguage = Self.detectSystemLanguage()
        }
        
        // Initialize bundle (thread-safe) - this is the most important part
        updateBundle(for: initialLanguage)
        
        // Note: currentLanguage will be initialized to .english by default
        // and can be updated later when accessed from MainActor context
    }
    
    nonisolated private func updateBundle(for language: AppLanguage) {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if localization not found
            self.bundle = Bundle.main
            return
        }
        self.bundle = bundle
    }
    
    @MainActor
    private func updateBundle() {
        updateBundle(for: currentLanguage)
    }
    
    static func detectSystemLanguage() -> AppLanguage {
        let preferredLanguages = Locale.preferredLanguages
        for langCode in preferredLanguages {
            // Try exact match first
            if let lang = AppLanguage(rawValue: langCode) {
                return lang
            }
            // Try base language (e.g., "zh" from "zh-Hans")
            let baseLang = String(langCode.prefix(2))
            if let lang = AppLanguage.allCases.first(where: { $0.rawValue.hasPrefix(baseLang) }) {
                return lang
            }
        }
        // Default to English
        return .english
    }
    
    nonisolated func localizedString(forKey key: String, value: String? = nil) -> String {
        // Thread-safe access to bundle
        bundleLock.lock()
        let bundle = self.bundle ?? Bundle.main
        bundleLock.unlock()
        return bundle.localizedString(forKey: key, value: value ?? key, table: nil)
    }
    
    // Nonisolated helper to get localized string without Main Actor requirement
    nonisolated static func getLocalizedString(forKey key: String, value: String? = nil) -> String {
        // Access shared's bundle directly (it's nonisolated(unsafe), so this is safe)
        // shared is also nonisolated(unsafe), so we can access it directly
        return shared.localizedString(forKey: key, value: value)
    }
}

// MARK: - String Extension

extension String {
    var localized: String {
        // Use nonisolated static method to avoid Main Actor issues
        return LocalizationManager.getLocalizedString(forKey: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}
