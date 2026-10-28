import Foundation

/// The languages Oriel offers, their names, and the normalization every provider relies on.
enum LanguageCatalog {
    /// Target languages offered in the pickers: ones Apple Translation, DeepL and Google all support and that LLMs
    /// handle well. Any BCP 47 code still works through the CLI.
    static let targets = [
        "en", "ja", "zh-Hans", "zh-Hant", "ko", "fr", "de", "es", "it", "pt-BR", "pt-PT", "nl", "ru", "uk", "pl",
        "tr", "ar", "hi", "th", "vi", "id", "sv", "da", "nb", "fi", "cs", "el", "he", "hu", "ro", "ms",
    ]

    /// The language's name in the user's language ("Japanese", "Chinese, Simplified").
    static func name(of code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    /// The language's English name, for LLM prompts.
    static func englishName(of language: Locale.Language) -> String {
        let code = code(for: language)
        return Locale(identifier: "en_US").localizedString(forIdentifier: code) ?? code
    }

    /// The code Oriel stores and sends: the language, plus the script for Chinese and the region for English and
    /// Portuguese, where providers distinguish them (`zh-Hant`, `pt-BR`, `en-GB`).
    static func code(for language: Locale.Language) -> String {
        guard let base = language.languageCode?.identifier.lowercased() else { return language.minimalIdentifier }
        switch base {
        case "zh":
            return isTraditionalChinese(language) ? "zh-Hant" : "zh-Hans"
        case "en", "pt":
            guard let region = language.region?.identifier else { return base }
            return "\(base)-\(region)"
        default:
            return base
        }
    }

    /// Parses a stored or typed code; empty means the system language.
    static func language(for code: String) -> Locale.Language {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? systemLanguage : Locale.Language(identifier: trimmed)
    }

    /// The first of the user's preferred languages.
    static var systemLanguage: Locale.Language {
        let preferred = Locale.preferredLanguages.first.map(Locale.Language.init(identifier:)) ?? Locale.Language(identifier: "en")
        return Locale.Language(identifier: code(for: preferred))
    }

    /// Whether text in `lhs` needs no translation into `rhs`: same language, and for Chinese the same script.
    /// Regional variants (en-GB and en-US) count as the same.
    static func isSameLanguage(_ lhs: Locale.Language, _ rhs: Locale.Language) -> Bool {
        guard let left = lhs.languageCode, let right = rhs.languageCode, left == right else { return false }
        return left.identifier != "zh" || isTraditionalChinese(lhs) == isTraditionalChinese(rhs)
    }

    static func isTraditionalChinese(_ language: Locale.Language) -> Bool {
        if let script = language.script {
            return script.identifier == "Hant"
        }
        return ["TW", "HK", "MO"].contains(language.region?.identifier ?? "")
    }

    /// Whether text in this language is written right to left (Arabic, Hebrew, Persian, Urdu).
    static func isRightToLeft(_ language: Locale.Language) -> Bool {
        language.characterDirection == .rightToLeft
    }
}
