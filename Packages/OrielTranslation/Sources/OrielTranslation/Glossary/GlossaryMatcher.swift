import Foundation

/// Finds glossary terms in text the way a reader would: as whole words in languages written with spaces ("cat" is not
/// in "category"), anywhere in Chinese, Japanese, Korean, Thai and the other scripts that do not separate words;
/// ignoring case unless the term says otherwise; and the longest term where two overlap ("New York" over "York").
enum GlossaryMatcher {
    struct Match: Equatable, Sendable {
        let range: Range<String.Index>
        let term: GlossaryTerm
    }

    /// The terms found in `text`, in text order, without overlaps.
    static func matches(_ terms: [GlossaryTerm], in text: String) -> [Match] {
        guard !text.isEmpty else { return [] }
        var candidates: [(match: Match, order: Int)] = []
        for (order, term) in terms.enumerated() where term.isUsable {
            let needle = term.trimmedSource
            let options: String.CompareOptions = term.isCaseSensitive ? [] : [.caseInsensitive]
            var start = text.startIndex
            while start < text.endIndex, let range = text.range(of: needle, options: options, range: start ..< text.endIndex) {
                if !range.isEmpty, isWholeWord(range, in: text) {
                    candidates.append((Match(range: range, term: term), order))
                }
                start = text.index(after: range.lowerBound)
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.match.range.lowerBound != rhs.match.range.lowerBound {
                return lhs.match.range.lowerBound < rhs.match.range.lowerBound
            }
            if lhs.match.range.upperBound != rhs.match.range.upperBound {
                return lhs.match.range.upperBound > rhs.match.range.upperBound
            }
            return lhs.order < rhs.order
        }
        var matches: [Match] = []
        var end = text.startIndex
        for candidate in candidates where candidate.match.range.lowerBound >= end {
            matches.append(candidate.match)
            end = candidate.match.range.upperBound
        }
        return matches
    }

    /// The terms of `terms` found in any of `texts`, in glossary order. A term found only inside a longer one
    /// ("York" in "New York") does not count.
    static func occurring(_ terms: [GlossaryTerm], in texts: [String]) -> [GlossaryTerm] {
        var found = Set<UUID>()
        for text in texts {
            for match in matches(terms, in: text) {
                found.insert(match.term.id)
            }
        }
        return terms.filter { found.contains($0.id) }
    }

    /// A match counts only where it does not continue a word on either side.
    private static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let first = text[range.lowerBound]
        let last = text[text.index(before: range.upperBound)]
        if range.lowerBound > text.startIndex, joinsWord(first, text[text.index(before: range.lowerBound)]) {
            return false
        }
        if range.upperBound < text.endIndex, joinsWord(last, text[range.upperBound]) {
            return false
        }
        return true
    }

    /// Whether two neighbouring characters are part of the same word: both letters or digits, in scripts that put
    /// spaces between words.
    static func joinsWord(_ lhs: Character, _ rhs: Character) -> Bool {
        isWordCharacter(lhs) && isWordCharacter(rhs) && !isUnspaced(lhs) && !isUnspaced(rhs)
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Chinese, Japanese, Korean, Thai, Lao, Khmer and Myanmar text, where a term can sit inside a longer run.
    static func isUnspaced(_ character: Character) -> Bool {
        guard let value = character.unicodeScalars.first?.value else { return false }
        return unspacedRanges.contains { $0.contains(value) }
    }

    private static let unspacedRanges: [ClosedRange<UInt32>] = [
        0x0E00 ... 0x0EFF, // Thai, Lao
        0x1000 ... 0x109F, // Myanmar
        0x1100 ... 0x11FF, // Hangul Jamo
        0x1780 ... 0x17FF, // Khmer
        0x3040 ... 0x30FF, // Hiragana, Katakana
        0x3130 ... 0x318F, // Hangul compatibility Jamo
        0x31F0 ... 0x31FF, // Katakana phonetic extensions
        0x3400 ... 0x4DBF, // CJK extension A
        0x4E00 ... 0x9FFF, // CJK unified ideographs
        0xAC00 ... 0xD7AF, // Hangul syllables
        0xF900 ... 0xFAFF, // CJK compatibility ideographs
        0xFF66 ... 0xFF9F, // half-width Katakana
        0x20000 ... 0x2FA1F, // CJK extensions B and later
    ]
}
