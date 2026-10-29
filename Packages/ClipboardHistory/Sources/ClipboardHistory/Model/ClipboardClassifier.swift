import AppKit
import CryptoKit
import Foundation
import SharedUI
import UniformTypeIdentifiers

/// Works out what a copy holds: its kind, a one-line title, the text to search, and the hash that tells a repeat
/// copy from a new one.
nonisolated enum ClipboardClassifier {
    /// The most text an item's description keeps for search; the whole text stays in its contents.
    static let textLimit = 10000
    static let titleLimit = 300

    struct Result: Sendable, Equatable {
        var kind: ClipboardKind
        var title: String
        var text: String?
        var contentHash: String
        var pixelWidth: Int?
        var pixelHeight: Int?
        var fileURLs: [URL]?
        var colorHex: String?
    }

    /// Nil when there is nothing to keep. `label` names an image or other data ("Screenshot").
    static func classify(_ snapshot: PasteboardSnapshot, label: String? = nil) -> Result? {
        guard !snapshot.isEmpty else { return nil }
        let files = fileURLs(in: snapshot)
        if !files.isEmpty {
            return describeFiles(files)
        }
        let text = plainText(of: snapshot)
        let imageType = ClipboardImages.preferredType(among: snapshot.types)
        if let imageType, let data = snapshot.data(for: imageType), imageWins(over: text, in: snapshot) {
            return describeImage(data, type: imageType, label: label)
        }
        if let text, !text.isEmpty {
            return describeText(text, in: snapshot)
        }
        if let data = snapshot.data(for: ClipboardTypes.color), let color = color(fromArchive: data) {
            let hash = digest("text", Data(color.hex.utf8))
            return Result(kind: .color, title: color.hex, text: color.hex, contentHash: hash, colorHex: color.hex)
        }
        return describeOther(snapshot, label: label)
    }

    /// The copy's text: plain UTF-8 or UTF-16 text, else the text of its RTF, RTFD or HTML, else its URL.
    static func plainText(of snapshot: PasteboardSnapshot) -> String? {
        if let data = snapshot.data(for: ClipboardTypes.plainText), let text = String(data: data, encoding: .utf8) {
            return text
        }
        for type in [ClipboardTypes.utf16Text, ClipboardTypes.utf16ExternalText] {
            if let data = snapshot.data(for: type), let text = String(data: data, encoding: .utf16) {
                return text
            }
        }
        if let data = snapshot.data(for: ClipboardTypes.rtf), let text = NSAttributedString(rtf: data, documentAttributes: nil)?.string {
            return text
        }
        if let data = snapshot.data(for: ClipboardTypes.rtfd), let text = NSAttributedString(rtfd: data, documentAttributes: nil)?.string {
            return text
        }
        if let data = snapshot.data(for: ClipboardTypes.html), let html = String(data: data, encoding: .utf8) {
            let text = strippingTags(html)
            return text.isEmpty ? nil : text
        }
        return snapshot.data(for: ClipboardTypes.url).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// File URLs of every item, file-reference URLs resolved to paths.
    static func fileURLs(in snapshot: PasteboardSnapshot) -> [URL] {
        snapshot.items.compactMap { item -> URL? in
            guard let data = item.first(where: { $0.type == ClipboardTypes.fileURL })?.data,
                  let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL
            else { return nil }
            return (url as NSURL).filePathURL ?? url
        }
    }

    /// One line: the first line with text, its runs of spaces collapsed, cut at `titleLimit` characters.
    static func title(for text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .first { !$0.isEmpty }
        guard let line else { return text.isEmpty ? "Empty Text" : "Spaces and Line Breaks" }
        return line.count > titleLimit ? String(line.prefix(titleLimit)) + "…" : line
    }

    /// A web, mail or app link and nothing else, such as `https://example.com/a`, `mailto:me@example.com`,
    /// `vscode://file/a.swift` or `www.example.com`.
    static func isLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4096, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }
        if trimmed.lowercased().hasPrefix("www."), trimmed.dropFirst(4).contains(".") {
            return true
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        switch scheme {
        case "http", "https", "ftp", "sftp", "ssh", "ws", "wss":
            return !(url.host() ?? "").isEmpty
        case "mailto", "tel", "sms", "facetime", "maps", "file":
            return trimmed.count > scheme.count + 1
        default:
            return trimmed.contains("://") && trimmed.count > scheme.count + 3
        }
    }

    // MARK: Kinds

    private static func describeFiles(_ urls: [URL]) -> Result {
        let names = urls.map(\.lastPathComponent)
        let title = names.count == 1 ? names[0] : "\(names[0]) and \(names.count - 1) more"
        let paths = urls.map(\.path).joined(separator: "\n")
        let hash = digest("files", Data(urls.map(\.absoluteString).joined(separator: "\n").utf8))
        return Result(kind: .files, title: title, text: String(paths.prefix(textLimit)), contentHash: hash, fileURLs: urls)
    }

    private static func describeImage(_ data: Data, type: String, label: String?) -> Result {
        let size = ClipboardImages.pixelSize(of: data, type: type)
        let name = label ?? (type == ClipboardTypes.pdf ? "PDF" : "Image")
        return Result(
            kind: .image,
            title: size.map { "\(name) · \($0.width) × \($0.height)" } ?? name,
            text: nil,
            contentHash: digest("image", data),
            pixelWidth: size?.width,
            pixelHeight: size?.height
        )
    }

    private static func describeText(_ text: String, in snapshot: PasteboardSnapshot) -> Result {
        let hash = digest("text", Data(text.utf8))
        let kept = String(text.prefix(textLimit))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = ClipboardColor(parsing: text) {
            return Result(kind: .color, title: trimmed, text: kept, contentHash: hash, colorHex: color.hex)
        }
        if isLink(text) {
            return Result(kind: .link, title: trimmed, text: kept, contentHash: hash)
        }
        let formatted = [ClipboardTypes.rtf, ClipboardTypes.rtfd, ClipboardTypes.html].contains { snapshot.data(for: $0) != nil }
        return Result(kind: formatted ? .richText : .text, title: title(for: text), text: kept, contentHash: hash)
    }

    private static func describeOther(_ snapshot: PasteboardSnapshot, label: String?) -> Result {
        var hasher = SHA256()
        hasher.update(data: Data("other".utf8))
        for representation in snapshot.items.joined() {
            hasher.update(data: Data(representation.type.utf8))
            hasher.update(data: representation.data)
        }
        return Result(kind: .other, title: label ?? describe(snapshot.types), text: nil, contentHash: hex(hasher.finalize()))
    }

    // MARK: Helpers

    /// An image wins over text that is missing, blank, or only the image's address with no formatted text next to it,
    /// as when a browser copies an image.
    private static func imageWins(over text: String?, in snapshot: PasteboardSnapshot) -> Bool {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        let formatted = snapshot.data(for: ClipboardTypes.rtf) != nil || snapshot.data(for: ClipboardTypes.html) != nil
        return !formatted && isLink(text)
    }

    private static func describe(_ types: [String]) -> String {
        for type in types where !type.hasPrefix("dyn.") {
            if let description = UTType(type)?.localizedDescription, !description.isEmpty {
                return description.prefix(1).uppercased() + description.dropFirst()
            }
        }
        return "Clipboard Data"
    }

    private static func color(fromArchive data: Data) -> ClipboardColor? {
        guard let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data),
              let color = archived.usingColorSpace(.sRGB)
        else { return nil }
        return ClipboardColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }

    private static func strippingTags(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // In order: &amp; last, so "&amp;lt;" becomes "&lt;" and not "<".
        let entities = [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func digest(_ kind: String, _ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.utf8))
        hasher.update(data: data)
        return hex(hasher.finalize())
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
