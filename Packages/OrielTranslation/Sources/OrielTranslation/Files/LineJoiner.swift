/// Joins the lines of one paragraph into running text, the way it was written before it was wrapped: OCR lines,
/// PDF lines and hard-wrapped text files all need it, because translators work much better on whole sentences.
enum LineJoiner {
    /// A hyphen at a line's end before a lowercase letter is a broken word and goes; Chinese, Japanese and the other
    /// unspaced scripts join without a space; everything else with one.
    static func join(_ lines: [String]) -> String {
        var result = ""
        for line in lines {
            let piece = line.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { continue }
            guard let last = result.last, let first = piece.first else {
                result = piece
                continue
            }
            let hyphen = last == "-" || last == "\u{00AD}"
            let brokenWord = hyphen && first.isLowercase && result.dropLast().last.map(\.isLetter) == true
            if brokenWord {
                result.removeLast()
                result += piece
            } else if GlossaryMatcher.isUnspaced(last) || GlossaryMatcher.isUnspaced(first) || isFullWidthPunctuation(last) {
                result += piece
            } else {
                result += " " + piece
            }
        }
        return result
    }

    /// `。`, `、`, `」` and the like end a line in CJK text without wanting a space after them.
    private static func isFullWidthPunctuation(_ character: Character) -> Bool {
        guard let value = character.unicodeScalars.first?.value else { return false }
        return (0x3000 ... 0x303F).contains(value) || (0xFF00 ... 0xFF65).contains(value)
    }
}
