import AppKit
import UniformTypeIdentifiers

/// Every write Oriel makes to the general pasteboard goes through here, so each copy is announced to Clipboard
/// History (`writes()`), which keeps it even while macOS stops Oriel from reading what other apps copy.
public enum Pasteboard {
    /// The general pasteboard's change count after Oriel's latest write, so a watcher can tell Oriel's copies from
    /// other apps'.
    public private(set) static var lastWriteChangeCount: Int?

    private static var listeners: [UUID: AsyncStream<PasteboardWrite>.Continuation] = [:]

    /// Copies an image as PNG and TIFF, so both modern apps and older ones can paste it (PLAN §7.5). `label` names
    /// it in Clipboard History ("Screenshot").
    @discardableResult
    public static func copy(_ image: CGImage, label: String? = nil) -> Bool {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        var item = [PasteboardSnapshot.Representation(type: NSPasteboard.PasteboardType.png.rawValue, data: png)]
        if let tiff = rep.tiffRepresentation {
            item.append(PasteboardSnapshot.Representation(type: NSPasteboard.PasteboardType.tiff.rawValue, data: tiff))
        }
        return write(PasteboardSnapshot(items: [item]), label: label)
    }

    @discardableResult
    public static func copy(_ text: String) -> Bool {
        write(PasteboardSnapshot(text: text))
    }

    /// Copies files the way Finder does, so they paste as files in Finder and Mail and as paths in a text field.
    @discardableResult
    public static func copy(fileURLs urls: [URL]) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls.map { $0 as NSURL }) else { return false }
        let items = urls.map { url in
            [
                PasteboardSnapshot.Representation(type: NSPasteboard.PasteboardType.fileURL.rawValue, data: Data(url.absoluteString.utf8)),
                PasteboardSnapshot.Representation(type: PasteboardSnapshot.plainText, data: Data(url.path.utf8)),
            ]
        }
        didWrite(PasteboardSnapshot(items: items), to: pasteboard, label: nil, announces: true)
        return true
    }

    /// Replaces the pasteboard's contents with `snapshot`. A write to the general pasteboard is announced to
    /// `writes()` unless `announces` is false, as when Clipboard History puts back an item it already keeps.
    @discardableResult
    public static func write(
        _ snapshot: PasteboardSnapshot,
        label: String? = nil,
        announces: Bool = true,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        let objects = snapshot.items.map { representations in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
            }
            return item
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(objects) else { return false }
        didWrite(snapshot, to: pasteboard, label: label, announces: announces)
        return true
    }

    /// Oriel's copies to the general pasteboard from now on, for Clipboard History. Each call returns its own stream,
    /// which ends when the task iterating it is cancelled.
    public static func writes() -> AsyncStream<PasteboardWrite> {
        let (stream, continuation) = AsyncStream.makeStream(of: PasteboardWrite.self, bufferingPolicy: .bufferingNewest(16))
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor in listeners[id] = nil }
        }
        return stream
    }

    /// An image on the pasteboard, if there is one.
    public static func image() -> CGImage? {
        NSImage(pasteboard: .general)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Hands `write` to every `writes()` stream.
    static func announce(_ write: PasteboardWrite) {
        for listener in listeners.values {
            listener.yield(write)
        }
    }

    private static func didWrite(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard, label: String?, announces: Bool) {
        guard pasteboard.name == .general else { return }
        let changeCount = pasteboard.changeCount
        lastWriteChangeCount = changeCount
        if announces {
            announce(PasteboardWrite(snapshot: snapshot, changeCount: changeCount, label: label))
        }
    }
}
