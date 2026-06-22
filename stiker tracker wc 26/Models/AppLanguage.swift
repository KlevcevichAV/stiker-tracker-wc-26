import SwiftUI

/// Выбранный язык интерфейса.
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case russian = "ru"

    var displayName: String {
        switch self {
        case .system:  return "System / Системный"
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

// MARK: - EnvironmentKey

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .system
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

// MARK: - Helper

extension AppLanguage {
    /// Возвращает true если нужен русский с учётом системного языка.
    var isRussian: Bool {
        switch self {
        case .russian: return true
        case .english: return false
        case .system:
            return Locale.current.language.languageCode?.identifier == "ru"
        }
    }
}
