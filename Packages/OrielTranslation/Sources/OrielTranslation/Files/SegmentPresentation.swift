import AppKit

/// How the file window shows a segment, so the table reads like the document: headings in semibold, list items with
/// their bullet or number, quotes in italics, code in a monospaced face without its fences, and a placeholder while a
/// translation is on its way. The table measures rows with the same text and fonts.
struct SegmentPresentation {
    enum Kind {
        case text, heading, quote, code
    }

    let original: String
    let translation: String
    let kind: Kind
    /// The translation is not there (yet).
    let isPending: Bool

    init(_ segment: DocumentSegment, translation: String?, isFinished: Bool) {
        if let verbatim = segment.verbatim {
            let code = Self.withoutFences(verbatim)
            original = code
            self.translation = code
            kind = .code
            isPending = false
            return
        }
        let prefix = segment.prefix
        kind = prefix.hasPrefix("#") ? .heading : prefix.contains(">") ? .quote : .text
        let marker = Self.marker(for: prefix)
        original = marker + segment.text
        if let translation {
            self.translation = marker + translation
            isPending = false
        } else {
            self.translation = isFinished ? "Not translated" : "…"
            isPending = true
        }
    }

    var font: NSFont {
        let size = NSFont.systemFontSize
        switch kind {
        case .text: return .systemFont(ofSize: size)
        case .heading: return .systemFont(ofSize: size, weight: .semibold)
        case .quote:
            let regular = NSFont.systemFont(ofSize: size)
            return NSFont(descriptor: regular.fontDescriptor.withSymbolicTraits(.italic), size: size) ?? regular
        case .code: return .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        }
    }

    var originalColor: NSColor {
        .secondaryLabelColor
    }

    var translationColor: NSColor {
        if isPending {
            return .tertiaryLabelColor
        }
        return kind == .code ? .secondaryLabelColor : .labelColor
    }

    /// `- ` → `• `, `2. ` stays, `- [ ] ` → `☐ `, indentation kept; headings and quotes show no marker.
    static func marker(for prefix: String) -> String {
        let indent = String(prefix.prefix { $0 == " " })
        let marker = prefix.drop { $0 == " " }.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespaces)
        guard !marker.isEmpty, !marker.hasPrefix("#") else { return "" }
        if marker.hasSuffix("[ ]") {
            return indent + "☐ "
        }
        if marker.hasSuffix("[x]") || marker.hasSuffix("[X]") {
            return indent + "☑ "
        }
        if ["-", "*", "+"].contains(marker) {
            return indent + "• "
        }
        return indent + marker + " "
    }

    /// A fenced code block's lines without the fences.
    static func withoutFences(_ block: String) -> String {
        var lines = block.split(separator: "\n", omittingEmptySubsequences: false)
        let isFence = { (line: Substring) in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("```") || line.trimmingCharacters(in: .whitespaces).hasPrefix("~~~")
        }
        if let first = lines.first, isFence(first) {
            lines.removeFirst()
        }
        if let last = lines.last, isFence(last) {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}
