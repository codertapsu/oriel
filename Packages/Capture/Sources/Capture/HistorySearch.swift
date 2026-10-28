import Foundation

/// Searching capture history by the text OCR found in the images, the app and the window title (PLAN §10.4, Snagit's
/// searchable library).
nonisolated enum HistorySearch {
    /// The entries that contain every word of `query`, ignoring case and diacritics; all of them for an empty query.
    static func filter(_ entries: [HistoryEntry], query: String) -> [HistoryEntry] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return entries }
        return entries.filter { entry in
            let haystack = [entry.recognizedText, entry.appName, entry.windowTitle, FilenameTemplate.kindName(entry.kind)]
                .compactMap(\.self)
                .joined(separator: "\n")
            return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// The entries older than `days` days at `now`; none when `days` is 0, which keeps everything.
    static func expired(_ entries: [HistoryEntry], keepingDays days: Int, now: Date) -> [HistoryEntry] {
        guard days > 0 else { return [] }
        let cutoff = now.addingTimeInterval(-Double(days) * 86400)
        return entries.filter { $0.date < cutoff }
    }
}
