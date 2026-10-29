import Foundation

/// The search field's matching: every word of the query must appear in the name, ignoring case and accents, so
/// "resume" finds "Résumé.pdf".
nonisolated enum TextMatch {
    static func words(of query: String) -> [String] {
        fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func matches(_ name: String, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let folded = fold(name)
        return words.allSatisfy { folded.contains($0) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
