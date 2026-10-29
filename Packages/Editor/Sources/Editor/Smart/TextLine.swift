import CoreGraphics
import OrielCore

/// A line of text OCR read in the base image, with its box in image space (points, top-left origin). The smart
/// tools work on these.
nonisolated struct TextLine: Sendable, Equatable {
    var text: String
    var rect: CGRect

    init(text: String, rect: CGRect) {
        self.text = text
        self.rect = rect
    }

    /// An OCR block (its box in the image's pixels) in the image space of a base image at `scale` pixels per point.
    init(_ block: OCRBlock, scale: CGFloat) {
        let scale = max(scale, 0.1)
        let box = block.boundingBox
        self.init(
            text: block.text,
            rect: CGRect(x: box.minX / scale, y: box.minY / scale, width: box.width / scale, height: box.height / scale)
        )
    }
}
