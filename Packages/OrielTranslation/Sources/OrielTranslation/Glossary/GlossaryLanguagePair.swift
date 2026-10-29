import Foundation

/// The terms of a glossary project for one direction, from `source` into `target`. An empty code means any language,
/// so "any language → any language" holds names that are never translated, and "any language → Japanese" terms that
/// read the same whatever the text was written in.
public struct GlossaryLanguagePair: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    /// A BCP 47 code, or empty for any language.
    public var source: String
    /// A BCP 47 code, or empty for any language.
    public var target: String
    public var terms: [GlossaryTerm]

    public init(id: UUID = UUID(), source: String, target: String, terms: [GlossaryTerm] = []) {
        self.id = id
        self.source = source
        self.target = target
        self.terms = terms
    }

    /// Whether the pair applies to a translation from `source` (nil when it is not known) into `target`. A pair with
    /// a fixed source never applies to text whose language is unknown.
    func applies(source: Locale.Language?, target: Locale.Language) -> Bool {
        let sourceMatches = self.source.isEmpty || source
            .map { LanguageCatalog.isSameLanguage(Locale.Language(identifier: self.source), $0) } == true
        let targetMatches = self.target.isEmpty || LanguageCatalog.isSameLanguage(Locale.Language(identifier: self.target), target)
        return sourceMatches && targetMatches
    }

    /// How specific the pair is: 2 when both languages are fixed, 0 for any → any. More specific pairs win.
    var specificity: Int {
        (source.isEmpty ? 0 : 1) + (target.isEmpty ? 0 : 1)
    }

    /// "English → Japanese", "Any language → Japanese".
    var title: String {
        "\(Self.name(of: source)) → \(Self.name(of: target))"
    }

    /// A language's name, or "Any language" for the empty code.
    static func name(of code: String) -> String {
        code.isEmpty ? "Any language" : LanguageCatalog.name(of: code)
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, target, terms
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            source: container.decodeIfPresent(String.self, forKey: .source) ?? "",
            target: container.decodeIfPresent(String.self, forKey: .target) ?? "",
            terms: container.decodeIfPresent([GlossaryTerm].self, forKey: .terms) ?? []
        )
    }
}
