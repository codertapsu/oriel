import Foundation

/// A glossary Oriel created on DeepL's servers for one project and language pair, kept in settings (per build, like
/// the API keys) so it is reused until the project's terms for that pair change.
struct DeepLGlossaryRecord: Codable, Sendable, Equatable {
    var glossaryID: String
    /// SHA-256 of the pair and its entries when the glossary was made; different terms mean a new glossary.
    var contentHash: String
    var projectID: UUID
    var created: Date
}
