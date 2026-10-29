import Foundation

/// Why a capture matched a history search: a line of its text around the first searched word found, with every
/// searched word in it marked, ignoring case and accents as the search does (PLAN §17).
nonisolated struct HistorySnippet: Sendable, Equatable {
    /// At most this many characters of the text, plus an ellipsis at each end that was cut.
    static let length = 90
    /// How much comes before the first match, so the match is near the start of the line.
    static let lead = 20

    /// One line: runs of spaces and line breaks are a single space.
    let text: String
    /// The searched words in `text`, in order, without overlaps.
    let highlights: [Range<String.Index>]

    /// The marked words, for tests and VoiceOver.
    var highlightedWords: [String] {
        highlights.map { String(text[$0]) }
    }

    /// The excerpt of `source` around the earliest of `terms`; nil when none of them is in it.
    static func make(from source: String, terms: [String]) -> HistorySnippet? {
        let words = terms.filter { !$0.isEmpty }
        let line = source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let found = words.compactMap { line.range(of: $0, options: Self.options) }.min { $0.lowerBound < $1.lowerBound }
        guard let match = found else { return nil }
        let count = line.count
        let matchStart = line.distance(from: line.startIndex, to: match.lowerBound)
        let matchEnd = line.distance(from: line.startIndex, to: match.upperBound)
        var start = max(0, matchStart - lead)
        if start + length > count {
            start = max(0, count - length)
        }
        start = wordStart(in: line, from: start, before: matchStart)
        let end = wordEnd(in: line, from: min(count, start + length), after: matchEnd)
        let window = line[line.index(line.startIndex, offsetBy: start) ..< line.index(line.startIndex, offsetBy: end)]
        let text = (start > 0 ? "…" : "") + window.trimmingCharacters(in: .whitespaces) + (end < count ? "…" : "")
        return HistorySnippet(text: text, highlights: occurrences(of: words, in: text))
    }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// `offset`, or the start of the next word when it falls inside one, but never past `limit`.
    private static func wordStart(in line: String, from offset: Int, before limit: Int) -> Int {
        guard offset > 0 else { return 0 }
        let characters = Array(line)
        var position = offset
        guard characters[position - 1] != " " else { return position }
        while position < limit, characters[position] != " " {
            position += 1
        }
        return position < limit ? position + 1 : offset
    }

    /// `offset`, or the end of the last whole word before it, but never before `limit`.
    private static func wordEnd(in line: String, from offset: Int, after limit: Int) -> Int {
        let characters = Array(line)
        guard offset < characters.count else { return characters.count }
        var position = offset
        while position > limit, characters[position] != " " {
            position -= 1
        }
        return position > limit ? position : max(offset, limit)
    }

    /// Every place a word appears in `text`, merged where they overlap.
    private static func occurrences(of words: [String], in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        for word in words {
            var from = text.startIndex
            while from < text.endIndex, let range = text.range(of: word, options: options, range: from ..< text.endIndex) {
                ranges.append(range)
                from = range.upperBound
            }
        }
        var merged: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
