import AppKit
import UniformTypeIdentifiers

/// What a drag out of the editor carries: the promised file and, for apps that take images rather than files,
/// the PNG itself.
struct DragPayload {
    /// The promised file's contents, in the default export format.
    let data: Data
    let fileName: String
    let contentType: UTType
    let pngData: Data?
    let preview: NSImage
}
