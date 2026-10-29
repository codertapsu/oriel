import Foundation

/// One entry of a glossary project (PLAN §17): how a term is always translated, within one language pair.
public struct GlossaryTerm: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    /// The term as it appears in the text that is translated.
    public var source: String
    /// What it always becomes. A term without a translation is kept in the editor but not applied.
    public var target: String
    /// Context for the people who edit the glossary, and for language models ("the UI noun, not the verb").
    public var note: String
    /// Whether "Apple" must not match "apple". Off by default, which suits most terms.
    public var isCaseSensitive: Bool

    public init(id: UUID = UUID(), source: String, target: String, note: String = "", isCaseSensitive: Bool = false) {
        self.id = id
        self.source = source
        self.target = target
        self.note = note
        self.isCaseSensitive = isCaseSensitive
    }

    /// Both sides have text, so the term can be applied.
    var isUsable: Bool {
        !trimmedSource.isEmpty && !trimmedTarget.isEmpty
    }

    var trimmedSource: String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTarget: String {
        target.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What two terms share when they are the same entry: the source, folded unless the term is case-sensitive.
    var matchKey: String {
        isCaseSensitive ? trimmedSource : trimmedSource.lowercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, target, note
        case isCaseSensitive = "caseSensitive"
    }

    /// Decodes leniently, so a file written by hand or by a later version still opens.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            source: container.decodeIfPresent(String.self, forKey: .source) ?? "",
            target: container.decodeIfPresent(String.self, forKey: .target) ?? "",
            note: container.decodeIfPresent(String.self, forKey: .note) ?? "",
            isCaseSensitive: container.decodeIfPresent(Bool.self, forKey: .isCaseSensitive) ?? false
        )
    }
}
