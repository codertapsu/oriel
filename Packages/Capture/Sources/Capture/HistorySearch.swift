import Foundation

/// Searching capture history by the text OCR found in the images, the app and the window title (PLAN §10.4, §17:
/// Snagit's searchable library). Every word of the query has to appear, ignoring case and diacritics; the fields are
/// folded once (`haystack(of:)`), so typing in the search field stays fast with thousands of captures.
nonisolated enum HistorySearch {
    /// The entries that contain every word of `query`; all of them for an empty query.
    static func filter(_ entries: [HistoryEntry], query: String) -> [HistoryEntry] {
        let terms = terms(in: query)
        guard !terms.isEmpty else { return entries }
        return entries.filter { matches(haystack(of: $0), terms: terms) }
    }

    /// The words of `query`, folded as haystacks are.
    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
    }

    /// Everything an entry can be found by, folded: the text OCR read, the app, the window title and how it was made.
    static func haystack(of entry: HistoryEntry) -> String {
        let fields = [entry.recognizedText, entry.appName, entry.windowTitle, FilenameTemplate.kindName(entry.kind)]
        return fold(fields.compactMap(\.self).joined(separator: "\n"))
    }

    static func matches(_ haystack: String, terms: [String]) -> Bool {
        terms.allSatisfy { haystack.contains($0) }
    }

    /// Why `entry` matched `query`: its text around the first word found, else its window title. Nil when it matched
    /// only by its app or kind, which its caption shows already.
    static func snippet(for entry: HistoryEntry, query: String) -> HistorySnippet? {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        for field in [entry.recognizedText, entry.windowTitle].compactMap(\.self) {
            if let snippet = HistorySnippet.make(from: field, terms: words) {
                return snippet
            }
        }
        return nil
    }

    /// The entries older than `days` days at `now`; none when `days` is 0, which keeps everything.
    static func expired(_ entries: [HistoryEntry], keepingDays days: Int, now: Date) -> [HistoryEntry] {
        guard days > 0 else { return [] }
        let cutoff = now.addingTimeInterval(-Double(days) * 86400)
        return entries.filter { $0.date < cutoff }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
