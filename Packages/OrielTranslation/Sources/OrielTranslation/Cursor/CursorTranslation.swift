import Foundation

/// What Translate Under Cursor shows for one piece of text.
struct CursorTranslation: Equatable, Sendable {
    let text: String
    let translation: String
    /// BCP 47; nil when the provider detected it.
    let sourceLanguage: String?
    let targetLanguage: String
    let providerName: String

    /// Text already in the target language: nothing is shown.
    var isSameLanguage: Bool {
        sourceLanguage.map { LanguageCatalog.isSameLanguage(.init(identifier: $0), .init(identifier: targetLanguage)) } ?? false
    }

    /// "Japanese → English · DeepL".
    var caption: String {
        let languages = [sourceLanguage.map(LanguageCatalog.name(of:)), LanguageCatalog.name(of: targetLanguage)].compactMap(\.self)
        return languages.joined(separator: " → ") + " · " + providerName
    }
}
