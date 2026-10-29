import CoreGraphics
import OrielCore

/// `oriel capture text --json`: the text, and every line Vision read with where it is on screen, so a script can
/// find a word and click it.
nonisolated struct TextCaptureReport: Encodable, Sendable {
    struct Line: Encodable, Sendable, Equatable {
        let text: String
        /// Global CoreGraphics points: the top-left of the main display is 0, 0 and y grows downwards.
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let confidence: Double
        /// BCP 47, when it could be told.
        let language: String?
    }

    let text: String
    let lines: [Line]

    /// `blocks` were read from an image of `area` (global points) at `scale` pixels per point.
    init(text: String, blocks: [OCRBlock], area: CGRect, scale: CGFloat) {
        self.text = text
        let scale = max(scale, 1)
        lines = blocks.map { block in
            let box = block.boundingBox
            return Line(
                text: block.text,
                x: Self.rounded(area.minX + box.minX / scale),
                y: Self.rounded(area.minY + box.minY / scale),
                width: Self.rounded(box.width / scale),
                height: Self.rounded(box.height / scale),
                confidence: Self.rounded(Double(block.confidence)),
                language: block.language
            )
        }
    }

    /// Two decimals are more than a point's worth.
    private static func rounded(_ value: some BinaryFloatingPoint) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}
