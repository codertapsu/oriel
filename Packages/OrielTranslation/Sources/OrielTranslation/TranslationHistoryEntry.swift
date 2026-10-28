import Foundation

/// One saved translation: what was translated, into what, by which provider. Stored as `entry.json` next to a
/// `thumbnail.png` in its own folder under `AppPaths.translationHistory`.
struct TranslationHistoryEntry: Codable, Sendable, Identifiable, Hashable {
    struct Block: Codable, Sendable, Hashable {
        let source: String
        let translation: String
    }

    let id: UUID
    let date: Date
    let providerID: String
    let providerName: String
    let sourceLanguage: String?
    let targetLanguage: String
    let blocks: [Block]

    /// The first lines of the translation, for lists.
    var summary: String {
        blocks.map(\.translation).joined(separator: " ").split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}
