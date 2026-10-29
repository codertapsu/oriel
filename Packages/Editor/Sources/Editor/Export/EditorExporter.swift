import CoreGraphics
import Foundation
import SharedUI

/// Turns a document into output: a flattened bitmap, an encoded PNG/JPEG/HEIC (through SharedUI's `ImageFile`,
/// with the capture's DPI) or a vector PDF. Everything goes through `EditorRenderer`.
enum EditorExporter {
    /// The flattened document at the base image's own resolution, or at exactly the pixel size the background's
    /// aspect asks for (X, LinkedIn, Instagram, a custom size).
    static func image(_ document: EditorDocument, matte: RGBAColor? = nil, effects: EffectCache? = nil) -> CGImage? {
        let scale = CanvasLayout(document: document).exportScale(baseScale: document.base.scale)
        return EditorRenderer.makeImage(document, scale: scale, options: RenderOptions(matte: matte), effects: effects)
    }

    static func data(for document: EditorDocument, format: EditorExportFormat, effects: EffectCache? = nil) -> Data? {
        guard let imageFormat = format.imageFormat else { return pdfData(document, effects: effects) }
        guard let image = image(document, matte: format.needsMatte ? .white : nil, effects: effects) else { return nil }
        return ImageFile.data(for: image, format: imageFormat, scale: dpiScale(of: document))
    }

    /// Pixels per point the file records as its DPI: the capture's, or 1 (72 DPI) for a fixed pixel size, which is
    /// what social networks expect.
    static func dpiScale(of document: EditorDocument) -> CGFloat {
        CanvasLayout(document: document).fixedPixelSize == nil ? document.base.scale : 1
    }

    /// A one-page PDF the size of the canvas in points. Annotations and text stay vectors; the base image and the
    /// effects are embedded at full resolution.
    static func pdfData(_ document: EditorDocument, effects: EffectCache? = nil) -> Data? {
        var mediaBox = CanvasLayout(document: document).canvasBounds
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }
        context.beginPDFPage(nil)
        EditorRenderer.render(document, into: context, scale: 1, effects: effects)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    static func write(_ document: EditorDocument, format: EditorExportFormat, to url: URL, effects: EffectCache? = nil) throws {
        guard let data = data(for: document, format: format, effects: effects) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: url])
        }
        try data.write(to: url, options: .atomic)
    }

    /// A file name from a window title, without characters that file systems or Finder reject.
    static func fileName(for title: String, fileExtension: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cleaned.isEmpty ? "Screenshot" : cleaned).\(fileExtension)"
    }
}
