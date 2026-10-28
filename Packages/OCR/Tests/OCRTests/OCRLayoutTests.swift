import CoreGraphics
@testable import OCR
import OrielCore
import Testing

struct OCRLayoutTests {
    private let size = CGSize(width: 1000, height: 1000)

    private func region(
        _ text: String,
        x: CGFloat,
        top: CGFloat,
        width: CGFloat = 0.2,
        height: CGFloat = 0.05,
        lines: Int = 1
    ) -> RecognizedRegion {
        // `top` is measured from the top of the image, like the pixel boxes the blocks end up with.
        RecognizedRegion(
            text: text,
            normalizedBox: CGRect(x: x, y: 1 - top - height, width: width, height: height),
            confidence: 0.9,
            lineCount: lines
        )
    }

    @Test func numbersBlocksFromOneAndConvertsBoxesToPixels() {
        let blocks = OCRLayout.blocks(
            from: [region("Hello world", x: 0.1, top: 0.1, lines: 2), region("Bonjour tout le monde", x: 0.1, top: 0.5)],
            imageSize: size,
            ordering: .asRecognized
        )
        #expect(blocks.map(\.id) == [1, 2])
        #expect(blocks[0].boundingBox == CGRect(x: 100, y: 100, width: 200, height: 50))
        #expect(blocks[0].lineCount == 2)
        #expect(blocks[1].boundingBox.minY == 500)
        #expect(blocks[1].language == "fr")
    }

    @Test func dropsEmptyTextAndRegionsThatRepeatAParagraph() {
        let paragraph = region("Name Quantity Price", x: 0.1, top: 0.1, width: 0.6, height: 0.1)
        let cell = region("Quantity", x: 0.3, top: 0.12, width: 0.1, height: 0.05)
        let blank = region("   ", x: 0.1, top: 0.8)
        let blocks = OCRLayout.blocks(from: [paragraph, cell, blank], imageSize: size, ordering: .asRecognized)
        #expect(blocks.map(\.text) == ["Name Quantity Price"])
    }

    @Test func keepsOverlappingRegionsWithDifferentText() {
        let first = region("Total", x: 0.1, top: 0.1)
        let second = region("Subtotal", x: 0.1, top: 0.1)
        #expect(OCRLayout.blocks(from: [first, second], imageSize: size, ordering: .asRecognized).count == 2)
    }

    @Test func readingOrderGoesRowByRowLeftToRight() {
        let boxes = [
            CGRect(x: 500, y: 12, width: 100, height: 20), // row 1, right
            CGRect(x: 10, y: 100, width: 100, height: 20), // row 2
            CGRect(x: 10, y: 10, width: 100, height: 20), // row 1, left
            CGRect(x: 300, y: 104, width: 100, height: 20), // row 2, right, slightly lower
        ]
        #expect(OCRLayout.readingOrder(boxes) == [2, 0, 1, 3])
    }

    @Test func fastModeLinesAreSortedIntoReadingOrder() {
        let blocks = OCRLayout.blocks(
            from: [region("second", x: 0.5, top: 0.1), region("third", x: 0.1, top: 0.3), region("first", x: 0.1, top: 0.1)],
            imageSize: size,
            ordering: .readingOrder
        )
        #expect(blocks.map(\.text) == ["first", "second", "third"])
        #expect(blocks.map(\.id) == [1, 2, 3])
    }
}
