import CryptoKit
import Foundation

/// What a DeepL glossary for one project and language pair must contain (`POST /v2/glossaries`): DeepL's lowercase
/// language codes and the entries as TSV, one `source<TAB>target` per line. DeepL refuses tabs, line breaks, leading or
/// trailing spaces and repeated sources, so entries are cleaned and the first of two equal sources wins.
struct DeepLGlossarySpec: Sendable, Equatable {
    let providerID: ProviderID
    let projectID: UUID
    let projectName: String
    /// DeepL's glossary codes: `en`, `ja`, `zh`.
    let source: String
    let target: String
    let entries: String
    let entryCount: Int

    /// Nil when the glossary has no usable term.
    init?(glossary: TranslationGlossary, providerID: ProviderID, source: Locale.Language, target: Locale.Language) {
        guard let projectID = glossary.projectID else { return nil }
        var seen = Set<String>()
        var lines: [String] = []
        for term in glossary.usableTerms {
            let from = Self.clean(term.trimmedSource)
            let to = Self.clean(term.trimmedTarget)
            guard !from.isEmpty, !to.isEmpty, seen.insert(from).inserted else { continue }
            lines.append("\(from)\t\(to)")
        }
        guard !lines.isEmpty else { return nil }
        self.providerID = providerID
        self.projectID = projectID
        projectName = glossary.projectName
        self.source = Self.code(for: source)
        self.target = Self.code(for: target)
        entries = lines.joined(separator: "\n")
        entryCount = lines.count
    }

    /// Where the glossary id is kept: provider, project and pair.
    var key: String {
        "\(providerID.rawValue)|\(projectID.uuidString)|\(pairKey)"
    }

    /// `en>ja`, as `/v2/glossary-language-pairs` lists pairs.
    var pairKey: String {
        "\(source)>\(target)"
    }

    var contentHash: String {
        let digest = SHA256.hash(data: Data("\(pairKey)\n\(entries)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// "Oriel · Docs · en→ja", as the glossary appears in the DeepL account.
    var name: String {
        let project = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Oriel · \(project.isEmpty ? "Glossary" : project) · \(source)→\(target)"
    }

    /// DeepL glossaries take the bare language, with Norwegian as `nb`.
    static func code(for language: Locale.Language) -> String {
        let base = language.languageCode?.identifier.lowercased() ?? LanguageCatalog.code(for: language).lowercased()
        return base == "no" || base == "nn" ? "nb" : base
    }

    private static func clean(_ text: String) -> String {
        let spaced = String(text.map { $0 == "\t" || $0.isNewline ? " " : $0 })
        return spaced.filter { !$0.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) }
            .trimmingCharacters(in: .whitespaces)
    }
}
