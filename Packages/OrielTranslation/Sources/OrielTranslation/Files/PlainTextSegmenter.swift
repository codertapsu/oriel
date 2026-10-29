/// Splits plain text into paragraphs, the text between blank lines. Hard-wrapped prose (every line but the last long,
/// no list markers) is joined back into one line, so it is translated as sentences; anything else (lists, addresses,
/// verse) keeps its line breaks.
enum PlainTextSegmenter {
    /// Lines at least this long, but for the last, read as wrapped prose.
    static let wrappedLineLength = 45

    static func segments(_ text: String, firstID: Int = 1) -> [DocumentSegment] {
        paragraphs(text).enumerated().map { DocumentSegment(id: firstID + $0.offset, text: $0.element) }
    }

    static func paragraphs(_ text: String) -> [String] {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        var paragraphs: [String] = []
        var lines: [String] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !lines.isEmpty {
                    paragraphs.append(paragraph(lines))
                    lines = []
                }
            } else {
                lines.append(trimmed)
            }
        }
        if !lines.isEmpty {
            paragraphs.append(paragraph(lines))
        }
        return paragraphs
    }

    private static func paragraph(_ lines: [String]) -> String {
        guard lines.count > 1, isWrappedProse(lines) else { return lines.joined(separator: "\n") }
        return LineJoiner.join(lines)
    }

    /// Every line but the last is long and none starts like a list item.
    static func isWrappedProse(_ lines: [String]) -> Bool {
        guard !lines.contains(where: startsListItem) else { return false }
        return lines.dropLast().allSatisfy { line in
            let length = line.count
            let dense = line.contains(where: GlossaryMatcher.isUnspaced)
            return length >= (dense ? wrappedLineLength / 2 : wrappedLineLength)
        }
    }

    /// `- `, `* `, `• `, `1. ` or `1) ` at the start.
    static func startsListItem(_ line: String) -> Bool {
        if ["- ", "* ", "• ", "+ ", "– "].contains(where: line.hasPrefix) {
            return true
        }
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return false }
        let rest = line.dropFirst(digits.count)
        return rest.hasPrefix(". ") || rest.hasPrefix(") ")
    }
}
