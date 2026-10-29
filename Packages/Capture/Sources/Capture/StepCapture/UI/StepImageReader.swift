import AppKit

/// An image dropped or pasted onto a step, such as the annotated result dragged back from the editor: PNG, TIFF or an
/// image file, with its scale from the image's own resolution (a 144 dpi PNG is a 2× capture).
enum StepImageReader {
    /// Whether `pasteboard` offers an image, from its types alone.
    static func canRead(_ pasteboard: NSPasteboard) -> Bool {
        NSImage.canInit(with: pasteboard)
    }

    static func image(from pasteboard: NSPasteboard) -> (image: CGImage, scale: CGFloat)? {
        guard let image = NSImage(pasteboard: pasteboard),
              let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }
        let width = image.size.width
        let scale = width > 0 ? max(1, (CGFloat(bitmap.width) / width).rounded()) : 1
        return (bitmap, scale)
    }
}
