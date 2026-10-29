import Foundation

/// What Capture Text's toast says it copied: the start of the text and how many lines it has, on one short line.
nonisolated enum TextPreview {
    /// The excerpt's length in characters, before its ellipsis.
    static let limit = 40

    /// "Copied “Screenshots are the fastest way to share…” · 3 lines".
    static func copiedMessage(for text: String) -> String {
        let lines = text.split(whereSeparator: \.isNewline).count { !$0.allSatisfy(\.isWhitespace) }
        let count = lines > 1 ? " · \(lines) lines" : ""
        return "Copied “\(excerpt(of: text))”\(count)"
    }

    /// The first line that has text, its spaces and tabs collapsed, cut after a whole word near `limit` characters.
    static func excerpt(of text: String) -> String {
        let first = text.split(whereSeparator: \.isNewline).first { !$0.allSatisfy(\.isWhitespace) } ?? ""
        let line = first.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard line.count > limit else { return line }
        let cut = line.index(line.startIndex, offsetBy: limit)
        var head = line[..<cut]
        if !line[cut].isWhitespace, let space = head.lastIndex(of: " "), line.distance(from: line.startIndex, to: space) >= limit / 2 {
            head = head[..<space]
        }
        return head.trimmingCharacters(in: .whitespaces) + "…"
    }
}
