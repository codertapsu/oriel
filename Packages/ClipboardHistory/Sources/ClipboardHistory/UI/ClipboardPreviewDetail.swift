import CoreGraphics
import Foundation

/// What a preview shows beyond the item's description, read and decoded off the main thread: the whole text, small
/// formatted text, a screen-sized image, the files' state, or the types of other data.
nonisolated struct ClipboardPreviewDetail: Sendable {
    /// One copied file as it is now.
    struct File: Sendable {
        let url: URL
        let exists: Bool
        /// What Finder calls it: "Application", "Folder", "PDF document"…
        let kind: String?
        /// Bytes, for a file; nil for a folder or a package.
        let size: Int?
    }

    /// One representation of other data.
    struct Representation: Sendable {
        let type: String
        let size: Int
    }

    /// The most text a preview lays out.
    static let textLimit = 200_000
    /// Formatted text bigger than this shows as plain text: laying it out would hold up the panel.
    static let richTextLimit = 256 * 1024
    static let imagePixels = 1600

    var text: String?
    var rtf: Data?
    var image: CGImage?
    var files: [File] = []
    var representations: [Representation] = []
    /// The contents could not be read (a damaged file).
    var isMissing = false

    static func load(_ item: ClipboardItem, from store: ClipboardStore) -> ClipboardPreviewDetail {
        var detail = ClipboardPreviewDetail()
        switch item.kind {
        case .files:
            detail.files = (item.fileURLs ?? []).prefix(50).map(file)
            return detail
        case .image:
            detail.image = store.image(of: item.id, maxPixels: imagePixels)
            detail.isMissing = detail.image == nil
            return detail
        case .text, .richText, .link, .color, .other:
            break
        }
        guard let content = store.content(of: item.id) else {
            detail.isMissing = true
            return detail
        }
        if item.kind == .other {
            detail.representations = content.items.first?.map { Representation(type: $0.type, size: $0.data.count) } ?? []
            return detail
        }
        detail.text = ClipboardClassifier.plainText(of: content).map { String($0.prefix(textLimit)) }
        if item.kind == .richText, let rtf = content.data(for: ClipboardTypes.rtf), rtf.count <= richTextLimit {
            detail.rtf = rtf
        }
        return detail
    }

    private static func file(_ url: URL) -> File {
        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey, .fileSizeKey, .isDirectoryKey])
        return File(
            url: url,
            exists: FileManager.default.fileExists(atPath: url.path),
            kind: values?.localizedTypeDescription,
            size: values?.isDirectory == true ? nil : values?.fileSize
        )
    }
}
