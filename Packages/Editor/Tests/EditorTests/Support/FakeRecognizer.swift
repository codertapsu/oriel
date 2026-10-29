import CoreGraphics
@testable import Editor
import OrielCore

/// OCR that returns the lines it was given, with their boxes in the image's pixels, and counts how often it ran.
actor FakeRecognizer: TextRecognizing {
    private let blocks: [OCRBlock]
    private(set) var calls = 0

    /// `lines`: text and box in image points; `scale` converts them to the pixels OCR reports.
    init(lines: [(String, CGRect)], scale: CGFloat) {
        blocks = lines.enumerated().map { index, line in
            let box = line.1
            return OCRBlock(
                id: index + 1,
                text: line.0,
                boundingBox: CGRect(x: box.minX * scale, y: box.minY * scale, width: box.width * scale, height: box.height * scale),
                confidence: 1
            )
        }
    }

    func recognize(_: CGImage, mode _: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
        calls += 1
        return blocks
    }
}
