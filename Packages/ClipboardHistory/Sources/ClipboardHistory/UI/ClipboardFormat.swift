import Foundation

/// How the panel and Settings write times, sizes and counts.
enum ClipboardFormat {
    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// "now", "2 min. ago", "yesterday"…
    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        now.timeIntervalSince(date) < 10 ? "now" : relative.localizedString(for: date, relativeTo: now)
    }

    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    static func count(_ number: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(number.formatted()) \(number == 1 ? singular : plural ?? singular + "s")"
    }

    /// What the information line under a preview says about an item's contents.
    static func summary(of item: ClipboardItem, text: String?) -> String {
        switch item.kind {
        case .link:
            let address = (text ?? item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return ([item.kind.displayName] + [URL(string: address)?.host()].compactMap(\.self)).joined(separator: " · ")
        case .color:
            return item.kind.displayName
        case .text, .richText:
            let text = text ?? item.text ?? ""
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            return [item.kind.displayName, count(text.count, "character"), count(words, "word"), count(lines, "line")]
                .joined(separator: " · ")
        case .image:
            let size = item.pixelWidth.flatMap { width in item.pixelHeight.map { "\(width) × \($0) px" } }
            return ([item.kind.displayName] + [size, bytes(item.byteCount)].compactMap(\.self)).joined(separator: " · ")
        case .files:
            return count(item.fileURLs?.count ?? 0, "file")
        case .other:
            return "Data · \(bytes(item.byteCount))"
        }
    }

    /// "Copied from Safari · 29 Oct 2026 at 14:03 · 3 times".
    static func provenance(of item: ClipboardItem) -> String {
        var parts = [
            item.sourceName.map { "Copied from \($0)" } ?? "Copied",
            item.lastCopied.formatted(date: .abbreviated, time: .shortened),
        ]
        if item.copyCount > 1 {
            parts.append("\(item.copyCount) times")
        }
        return parts.joined(separator: " · ")
    }
}
