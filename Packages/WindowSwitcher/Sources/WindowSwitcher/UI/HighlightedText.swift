import AppKit

/// Titles with their search matches in bold accent color (PLAN §7.1.10).
enum HighlightedText {
    static func make(
        _ text: String,
        matches: [Int],
        font: NSFont,
        color: NSColor,
        highlight: NSColor = .controlAccentColor
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        guard !matches.isEmpty else { return result }
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let wanted = Set(matches)
        var offset = 0
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if wanted.contains(offset) {
                result.addAttributes([.font: bold, .foregroundColor: highlight], range: NSRange(index ..< next, in: text))
            }
            offset += 1
            index = next
        }
        return result
    }
}
