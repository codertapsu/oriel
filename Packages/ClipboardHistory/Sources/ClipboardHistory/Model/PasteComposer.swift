import Foundation
import SharedUI

/// What goes on the clipboard when items are pasted or copied: one item as it was copied, or its plain text; several
/// at once as their texts on separate lines, or as one set of files.
nonisolated enum PasteComposer {
    /// An item with its contents.
    struct Entry: Sendable {
        let item: ClipboardItem
        let content: PasteboardSnapshot
    }

    static func compose(_ entries: [Entry], plainText: Bool) -> PasteboardSnapshot? {
        guard let first = entries.first else { return nil }
        if entries.allSatisfy({ $0.item.kind == .files }) {
            return files(entries.flatMap { $0.item.fileURLs ?? [] })
        }
        if entries.count == 1 {
            if plainText, first.item.kind.isTextual, let text = text(of: first) {
                return PasteboardSnapshot(text: text)
            }
            return first.content
        }
        let texts = entries.compactMap(text(of:))
        return texts.isEmpty ? first.content : PasteboardSnapshot(text: texts.joined(separator: "\n"))
    }

    /// The whole text of an item, from its contents rather than the shortened copy in its description; file paths for
    /// files; nil for images and other data.
    static func text(of entry: Entry) -> String? {
        switch entry.item.kind {
        case .files: entry.item.fileURLs.map { $0.map(\.path).joined(separator: "\n") }
        case .image, .other: nil
        case .text, .richText, .link, .color: ClipboardClassifier.plainText(of: entry.content) ?? entry.item.text
        }
    }

    /// Files as Finder copies them: one item each, its URL and its path. Built from the item's resolved paths, not
    /// the copied data, which can hold a file-reference URL.
    private static func files(_ urls: [URL]) -> PasteboardSnapshot? {
        guard !urls.isEmpty else { return nil }
        return PasteboardSnapshot(items: urls.map { url in
            [
                PasteboardSnapshot.Representation(type: ClipboardTypes.fileURL, data: Data(url.absoluteString.utf8)),
                PasteboardSnapshot.Representation(type: ClipboardTypes.plainText, data: Data(url.path.utf8)),
            ]
        })
    }
}
