import AppKit
import SharedUI

/// Reads a pasteboard into a snapshot. Call it off the main thread: another app's data can take a while to arrive (a
/// promise, a large image, Universal Clipboard), and macOS holds the read while it asks the user about Paste from
/// Other Apps.
nonisolated enum PasteboardReader {
    /// More than this is not kept; a representation that would go over it is left out.
    static let maxBytes = 64 << 20
    static let maxItems = 512

    enum Outcome: Sendable {
        case empty
        /// The copy carries a privacy marker, so nothing was read.
        case markedPrivate
        /// Every representation was over `maxBytes`.
        case tooLarge
        case snapshot(PasteboardSnapshot)
    }

    static func read(_ pasteboard: NSPasteboard) -> Outcome {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return .empty }
        let types = items.map { $0.types.map(\.rawValue) }
        // The types are looked at first, so a password a manager marked as concealed is never read at all.
        guard !PrivacyFilter.isMarkedPrivate(types.joined()) else { return .markedPrivate }
        var snapshot: [[PasteboardSnapshot.Representation]] = []
        var total = 0
        var leftOut = false
        for (item, itemTypes) in zip(items, types).prefix(maxItems) {
            var representations: [PasteboardSnapshot.Representation] = []
            for type in ClipboardTypes.kept(itemTypes) {
                guard let data = item.data(forType: NSPasteboard.PasteboardType(type)) else { continue }
                guard total + data.count <= maxBytes else {
                    leftOut = true
                    continue
                }
                total += data.count
                representations.append(PasteboardSnapshot.Representation(type: type, data: data))
            }
            if !representations.isEmpty {
                snapshot.append(representations)
            }
        }
        guard !snapshot.isEmpty else { return leftOut ? .tooLarge : .empty }
        return .snapshot(PasteboardSnapshot(items: snapshot))
    }
}
