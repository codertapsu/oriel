import Foundation

/// Subsequence fuzzy matching (PLAN §7.1.10): every query character must appear in order. Case- and
/// diacritic-insensitive. Each whitespace-separated word of the query matches on its own, so "safari git"
/// finds "GitHub — Safari". Pure and table-tested.
///
/// Scoring rewards consecutive runs, matches at word starts (after a space or punctuation, or at a lower-to-
/// upper case change) and at the very start, and charges a little for each skipped character.
nonisolated enum FuzzyMatcher {
    private static let matchScore = 10
    private static let consecutiveBonus = 15
    private static let wordStartBonus = 20
    private static let leadingBonus = 15
    private static let gapPenalty = 1
    private static let maximumGapPenalty = 15

    /// The best match of `query` in `text`, or nil when some word of the query does not match. An empty
    /// query matches everything with score 0.
    static func match(_ query: String, in text: String) -> FuzzyMatch? {
        let words = query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
        guard !words.isEmpty else { return FuzzyMatch(score: 0, indices: []) }
        let characters = Array(text)
        let folded = characters.map { fold(String($0)) }
        let starts = wordStarts(characters)
        var score = 0
        var indices = Set<Int>()
        for word in words {
            guard let match = bestMatch(of: word.map { String($0) }, in: folded, wordStarts: starts) else { return nil }
            score += match.score
            indices.formUnion(match.indices)
        }
        return FuzzyMatch(score: score, indices: indices.sorted())
    }

    /// The best-scoring alignment: a greedy match from every position where the first character occurs.
    private static func bestMatch(of word: [String], in text: [String], wordStarts: [Bool]) -> FuzzyMatch? {
        guard let first = word.first else { return nil }
        var best: FuzzyMatch?
        for start in text.indices where text[start] == first {
            guard let candidate = greedyMatch(of: word, in: text, from: start, wordStarts: wordStarts) else {
                // No later start can succeed when this one already ran out of text.
                break
            }
            if candidate.score > best?.score ?? Int.min {
                best = candidate
            }
        }
        return best
    }

    private static func greedyMatch(of word: [String], in text: [String], from start: Int, wordStarts: [Bool]) -> FuzzyMatch? {
        var indices: [Int] = []
        var position = start
        for character in word {
            while position < text.count, text[position] != character {
                position += 1
            }
            guard position < text.count else { return nil }
            indices.append(position)
            position += 1
        }
        var score = 0
        for (offset, index) in indices.enumerated() {
            score += matchScore
            if wordStarts[index] {
                score += wordStartBonus
            }
            if index == 0 {
                score += leadingBonus
            }
            if offset > 0 {
                let gap = index - indices[offset - 1] - 1
                score += gap == 0 ? consecutiveBonus : -min(gap * gapPenalty, maximumGapPenalty)
            }
        }
        return FuzzyMatch(score: score, indices: indices)
    }

    private static func wordStarts(_ characters: [Character]) -> [Bool] {
        characters.indices.map { index in
            guard index > 0 else { return true }
            let previous = characters[index - 1]
            let current = characters[index]
            if !previous.isLetter, !previous.isNumber {
                return current.isLetter || current.isNumber
            }
            return previous.isLowercase && current.isUppercase
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
