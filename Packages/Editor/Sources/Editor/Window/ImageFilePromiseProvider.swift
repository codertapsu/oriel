import AppKit

/// A file promise that also offers the image as PNG data, so a drop works both in the Finder (which takes the
/// file) and in apps that only accept image data.
///
/// `nonisolated` because NSFilePromiseProvider and its pasteboard methods are; it only reads immutable data.
final nonisolated class ImageFilePromiseProvider: NSFilePromiseProvider {
    private let imageData: Data?

    init(fileType: String, delegate: any NSFilePromiseProviderDelegate, imageData: Data?) {
        self.imageData = imageData
        super.init()
        self.fileType = fileType
        self.delegate = delegate
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = super.writableTypes(for: pasteboard)
        if imageData != nil, !types.contains(.png) {
            types.append(.png)
        }
        return types
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .png, let imageData {
            return imageData
        }
        return super.pasteboardPropertyList(forType: type)
    }
}
