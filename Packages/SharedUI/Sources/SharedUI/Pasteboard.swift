import AppKit
import UniformTypeIdentifiers

/// Writing captures and text to the general pasteboard.
public enum Pasteboard {
    /// Copies an image as PNG and TIFF, so both modern apps and older ones can paste it (PLAN §7.5).
    @discardableResult
    public static func copy(_ image: CGImage) -> Bool {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if let tiff = rep.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        return pasteboard.writeObjects([item])
    }

    @discardableResult
    public static func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    /// An image on the pasteboard, if there is one.
    public static func image() -> CGImage? {
        NSImage(pasteboard: .general)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
