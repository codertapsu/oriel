import CoreGraphics
import OrielCore
@testable import OrielTranslation
import Testing

/// Choosing the line or paragraph under a point from OCR boxes, and when to read a larger area.
struct CursorTextPickerTests {
    /// Two paragraphs in one column, a heading above them and a line in a second column.
    private let lines = [
        TextLine(text: "Heading", box: CGRect(x: 100, y: 60, width: 120, height: 24)),
        TextLine(text: "The first line of a para-", box: CGRect(x: 100, y: 100, width: 300, height: 16)),
        TextLine(text: "graph wraps onto the next", box: CGRect(x: 100, y: 120, width: 290, height: 16)),
        TextLine(text: "and ends here.", box: CGRect(x: 100, y: 140, width: 150, height: 16)),
        TextLine(text: "A new paragraph.", box: CGRect(x: 100, y: 180, width: 180, height: 16)),
        TextLine(text: "Sidebar text", box: CGRect(x: 520, y: 120, width: 120, height: 16)),
    ]

    @Test func picksTheLineUnderThePoint() throws {
        let pick = try #require(CursorTextPicker.pick(at: CGPoint(x: 150, y: 128), in: lines, unit: .line))
        #expect(pick.text == "graph wraps onto the next" && pick.region == lines[2].box)
        // A point just above or below a line, in the gap, still counts; far from text, nothing does.
        #expect(CursorTextPicker.pick(at: CGPoint(x: 150, y: 118), in: lines, unit: .line)?.text == "graph wraps onto the next")
        #expect(CursorTextPicker.pick(at: CGPoint(x: 450, y: 300), in: lines, unit: .line) == nil)
    }

    @Test func picksTheWholeParagraphJoinedAsRunningText() throws {
        let pick = try #require(CursorTextPicker.pick(at: CGPoint(x: 150, y: 148), in: lines, unit: .paragraph))
        #expect(pick.text == "The first line of a paragraph wraps onto the next and ends here.")
        #expect(pick.region == CGRect(x: 100, y: 100, width: 300, height: 56))
        #expect(CursorTextPicker.pick(at: CGPoint(x: 130, y: 70), in: lines, unit: .paragraph)?.text == "Heading")
        #expect(CursorTextPicker.pick(at: CGPoint(x: 560, y: 125), in: lines, unit: .paragraph)?.text == "Sidebar text")
        #expect(CursorTextPicker.pick(at: CGPoint(x: 120, y: 185), in: lines, unit: .paragraph)?.text == "A new paragraph.")
    }

    @Test func joinsCJKLinesWithoutSpaces() throws {
        let japanese = [
            TextLine(text: "日本語の文章は改行されても", box: CGRect(x: 0, y: 0, width: 260, height: 18)),
            TextLine(text: "空白なしでつながります。", box: CGRect(x: 0, y: 22, width: 240, height: 18)),
        ]
        let pick = try #require(CursorTextPicker.pick(at: CGPoint(x: 20, y: 30), in: japanese, unit: .paragraph))
        #expect(pick.text == "日本語の文章は改行されても空白なしでつながります。")
    }

    @Test func convertsOCRPixelsToGlobalPoints() {
        let blocks = [OCRBlock(id: 1, text: " Hello ", boundingBox: CGRect(x: 40, y: 20, width: 200, height: 32), confidence: 1)]
        let converted = CursorTextPicker.lines(from: blocks, imageWidth: 1200, captureRect: CGRect(x: 300, y: 500, width: 600, height: 120))
        #expect(converted == [TextLine(text: "Hello", box: CGRect(x: 320, y: 510, width: 100, height: 16))])
    }

    @Test func growsWhenTheTextTouchesAnEdgeThatIsNotTheScreens() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let capture = CGRect(x: 300, y: 100, width: 600, height: 120)
        let cut = [TextLine(text: "cut off", box: CGRect(x: 300, y: 150, width: 600, height: 16))]
        let pick = try #require(CursorTextPicker.pick(at: CGPoint(x: 500, y: 155), in: cut, unit: .line))
        let wider = try #require(CursorTextPicker.grownRect(for: pick, capture: capture, screen: screen, unit: .line))
        #expect(wider == CGRect(x: 0, y: 100, width: 1400, height: 120))

        // At the screen's edge there is nothing more to read.
        let atEdge = CGRect(x: 0, y: 100, width: 600, height: 120)
        let edgePick = try #require(CursorTextPicker.pick(
            at: CGPoint(x: 100, y: 155),
            in: [TextLine(text: "edge", box: CGRect(x: 0, y: 150, width: 300, height: 16))],
            unit: .line
        ))
        #expect(CursorTextPicker.grownRect(for: edgePick, capture: atEdge, screen: screen, unit: .line) == nil)

        // A paragraph that reaches the capture's bottom grows downward by about eight lines.
        let tall = [
            TextLine(text: "top", box: CGRect(x: 400, y: 180, width: 200, height: 16)),
            TextLine(text: "bottom", box: CGRect(x: 400, y: 200, width: 200, height: 16)),
        ]
        let paragraph = try #require(CursorTextPicker.pick(at: CGPoint(x: 450, y: 185), in: tall, unit: .paragraph))
        let taller = try #require(CursorTextPicker.grownRect(for: paragraph, capture: capture, screen: screen, unit: .paragraph))
        #expect(taller == CGRect(x: 300, y: 100, width: 600, height: 248))
        // The same text inside the capture needs nothing more.
        let inside = try #require(CursorTextPicker.pick(at: CGPoint(x: 450, y: 145), in: [
            TextLine(text: "inside", box: CGRect(x: 400, y: 140, width: 200, height: 16)),
        ], unit: .paragraph))
        #expect(CursorTextPicker.grownRect(for: inside, capture: capture, screen: screen, unit: .paragraph) == nil)
    }

    @Test func groupsSequentialLinesIntoParagraphs() {
        let pageLines = [
            TextLine(text: "Title", box: CGRect(x: 72, y: 72, width: 200, height: 28)),
            TextLine(text: "Body line one", box: CGRect(x: 72, y: 120, width: 400, height: 14)),
            TextLine(text: "body line two", box: CGRect(x: 72, y: 137, width: 380, height: 14)),
            TextLine(text: "Next paragraph", box: CGRect(x: 72, y: 175, width: 400, height: 14)),
            TextLine(text: "Second column", box: CGRect(x: 320, y: 120, width: 200, height: 14)),
        ]
        #expect(TextLineGrouping.sequentialParagraphs(pageLines) == [[0], [1, 2], [3], [4]])
    }
}
