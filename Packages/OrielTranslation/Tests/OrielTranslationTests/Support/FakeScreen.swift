import CoreGraphics
import OrielCore
@testable import OrielTranslation

/// Text lines at places on a pretend screen (global points). Capturing a rect gives a 2× image of it; recognizing
/// that image gives the lines inside the rect as OCR blocks in the image's pixels, as Vision would.
@MainActor
final class FakeScreen {
    var lines: [TextLine]
    private(set) var captures: [CGRect] = []

    init(_ lines: [TextLine]) {
        self.lines = lines
    }

    func capture(_ rect: CGRect) throws -> CGImage {
        captures.append(rect)
        return try TestSupport.image(width: Int(rect.width * 2), height: Int(rect.height * 2))
    }

    /// The lines of the last capture, clipped to it, in its 2× pixels.
    func blocks() -> [OCRBlock] {
        guard let rect = captures.last else { return [] }
        return lines.enumerated().compactMap { index, line in
            let visible = line.box.intersection(rect)
            guard !visible.isNull, visible.width > 0 else { return nil }
            let pixels = CGRect(
                x: (visible.minX - rect.minX) * 2, y: (visible.minY - rect.minY) * 2, width: visible.width * 2, height: visible.height * 2
            )
            return OCRBlock(id: index + 1, text: line.text, boundingBox: pixels, confidence: 1)
        }
    }
}
