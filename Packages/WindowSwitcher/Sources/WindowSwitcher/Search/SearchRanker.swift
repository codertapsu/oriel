import Foundation

/// Filters and orders windows by a search query over "title app" (PLAN §7.1.10). Pure.
nonisolated enum SearchRanker {
    /// Matching windows, best first; equal scores keep the input (MRU) order. An empty query keeps every
    /// window in order, with nothing highlighted.
    static func rank(_ entries: [WindowEntry], query: String) -> [RankedWindow] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return entries.map { RankedWindow(entry: $0, score: 0, titleMatches: [], appMatches: []) }
        }
        let ranked = entries.enumerated().compactMap { offset, entry -> (offset: Int, window: RankedWindow)? in
            let title = entry.info.title
            let haystack = title + " " + entry.info.appName
            guard let match = FuzzyMatcher.match(trimmed, in: haystack) else { return nil }
            let titleLength = title.count
            let window = RankedWindow(
                entry: entry,
                score: match.score,
                titleMatches: match.indices.filter { $0 < titleLength },
                appMatches: match.indices.filter { $0 > titleLength }.map { $0 - titleLength - 1 }
            )
            return (offset, window)
        }
        return ranked
            .sorted { lhs, rhs in
                lhs.window.score == rhs.window.score ? lhs.offset < rhs.offset : lhs.window.score > rhs.window.score
            }
            .map(\.window)
    }
}
