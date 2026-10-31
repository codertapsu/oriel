import CoreGraphics
@testable import OCR
import Testing

/// Grouping what Vision read into blocks stays a small part of OCR's 400 ms (PLAN §9, §14.4 "OCR grouping of 500
/// lines"): 500 lines in two columns of a 2,000 × 3,000 px page, both orderings. Measured 50–60 ms, nearly all of it the
/// language of each line, read on every core; it was 320 ms with a recognizer made for each line, one after another.
@Suite(.serialized)
struct GroupingBudgetTests {
    private static let budget = Duration.milliseconds(150)

    /// Two columns of 250 lines each, in Vision's normalized, bottom-left space.
    private static let lines: [RecognizedRegion] = (0 ..< 500).map { index in
        let column = CGFloat(index / 250)
        let row = CGFloat(index % 250)
        return RecognizedRegion(
            text: "Line \(index) of a long document set in two columns",
            normalizedBox: CGRect(x: 0.05 + column * 0.5, y: 0.98 - row * 0.0038, width: 0.4, height: 0.003),
            confidence: 0.9,
            lineCount: 1
        )
    }

    @Test(arguments: [OCRLayout.Ordering.readingOrder, .asRecognized])
    func fiveHundredLinesGroupInsideTheBudget(_ ordering: OCRLayout.Ordering) {
        let clock = ContinuousClock()
        let page = CGSize(width: 2000, height: 3000)
        var count = 0
        let runs = (0 ..< 5).map { _ in
            clock.measure { count = OCRLayout.blocks(from: Self.lines, imageSize: page, ordering: ordering).count }
        }.sorted()
        let median = runs[runs.count / 2]
        print("OCR grouping, 500 lines, \(ordering): \(count) blocks, median \(median)")
        #expect(count == 500)
        #expect(median < Self.budget, "median \(median)")
    }
}
