import Foundation

/// A named glossary (PLAN §17), say one per product or client: its terms for each language pair, and optionally the
/// Google Cloud glossary that holds the same terms for Google.
public struct GlossaryProject: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var pairs: [GlossaryLanguagePair]
    /// A Cloud Translation glossary (`projects/…/locations/…/glossaries/…`, or its ID in us-central1 of the service
    /// account's project). Google providers with a service account key use it instead of the terms here; empty means
    /// none.
    public var googleGlossary: String

    public init(id: UUID = UUID(), name: String, pairs: [GlossaryLanguagePair] = [], googleGlossary: String = "") {
        self.id = id
        self.name = name
        self.pairs = pairs
        self.googleGlossary = googleGlossary
    }

    /// The usable terms for a translation from `source` (nil: unknown) into `target`: the most specific pair's first,
    /// and each source term once, so "English → Japanese" overrides "any language → Japanese". Two case-sensitive
    /// terms that differ only in case ("Apple", "apple") are both kept.
    func terms(source: Locale.Language?, target: Locale.Language) -> [GlossaryTerm] {
        let applicable = pairs.enumerated()
            .filter { $0.element.applies(source: source, target: target) }
            .sorted { ($0.element.specificity, -$0.offset) > ($1.element.specificity, -$1.offset) }
            .map(\.element)
        var exact = Set<String>()
        var folded = Set<String>()
        var foldedInsensitive = Set<String>()
        var terms: [GlossaryTerm] = []
        for pair in applicable {
            for term in pair.terms where term.isUsable {
                let key = term.trimmedSource
                let lowered = key.lowercased()
                let taken = term.isCaseSensitive ? exact.contains(key) || foldedInsensitive.contains(lowered) : folded.contains(lowered)
                guard !taken else { continue }
                exact.insert(key)
                folded.insert(lowered)
                if !term.isCaseSensitive {
                    foldedInsensitive.insert(lowered)
                }
                terms.append(term)
            }
        }
        return terms
    }

    /// The number of terms across every pair.
    var termCount: Int {
        pairs.reduce(0) { $0 + $1.terms.count }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, pairs, googleGlossary
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: container.decodeIfPresent(String.self, forKey: .name) ?? "Glossary",
            pairs: container.decodeIfPresent([GlossaryLanguagePair].self, forKey: .pairs) ?? [],
            googleGlossary: container.decodeIfPresent(String.self, forKey: .googleGlossary) ?? ""
        )
    }
}
