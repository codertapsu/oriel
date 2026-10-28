import CoreGraphics
import CoreText
import Foundation
@testable import OCR
import OrielCore
import Testing

/// Runs real Vision recognition on images drawn in memory. Vision needs no permission and shows nothing.
struct VisionTextRecognizerTests {
    /// A line of text to draw: `top` is the distance from the image's top edge to the top of the line, in pixels.
    private struct Line {
        let text: String
        let x: CGFloat
        let top: CGFloat
        let size: CGFloat

        init(_ text: String, x: CGFloat, top: CGFloat, size: CGFloat) {
            self.text = text
            self.x = x
            self.top = top
            self.size = size
        }
    }

    /// A white image with black Helvetica lines.
    private func render(_ lines: [Line], width: Int = 1200, height: Int = 600) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for line in lines {
            let font = CTFontCreateWithName("Helvetica" as CFString, line.size, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ]
            let attributed = try #require(CFAttributedStringCreate(nil, line.text as CFString, attributes as CFDictionary))
            let ctLine = CTLineCreateWithAttributedString(attributed)
            // CoreGraphics puts y = 0 at the bottom; the baseline sits one ascent below the line's top.
            context.textPosition = CGPoint(x: line.x, y: CGFloat(height) - line.top - CTFontGetAscent(font))
            CTLineDraw(ctLine, context)
        }
        return try #require(context.makeImage())
    }

    @Test(arguments: [OCRMode.fast, OCRMode.document])
    func recognizesRenderedTextWithTopLeftPixelBoxes(_ mode: OCRMode) async throws {
        let image = try render([Line("Hello world", x: 60, top: 80, size: 72)])
        let blocks = try await VisionTextRecognizer().recognize(image, mode: mode, languages: [])
        let block = try #require(blocks.first { $0.text.lowercased().contains("hello world") })
        #expect(block.id == 1)
        #expect(block.language == "en")
        // The text was drawn near the top-left, so its pixel box must be there too (a bottom-left box would not be).
        #expect(block.boundingBox.minX >= 40 && block.boundingBox.minX <= 80)
        #expect(block.boundingBox.minY >= 60 && block.boundingBox.maxY <= 200)
        #expect(block.boundingBox.width > 200 && block.boundingBox.maxX <= 1200)
    }

    @Test func documentModeGroupsWrappedLinesIntoOneParagraph() async throws {
        let image = try render([
            Line("Open the settings window to choose where", x: 60, top: 100, size: 40),
            Line("translations are saved on this Mac.", x: 60, top: 150, size: 40),
            Line("Second paragraph far below the first one.", x: 60, top: 420, size: 40),
        ])
        let blocks = try await VisionTextRecognizer().recognize(image, mode: .document, languages: ["en"])
        #expect(blocks.count == 2)
        let first = try #require(blocks.first)
        #expect(first.lineCount == 2)
        #expect(first.text.contains("settings") && first.text.contains("saved"))
        #expect(blocks.map(\.id) == [1, 2])
    }

    @Test func fastModeReturnsOneBlockPerLineInReadingOrder() async throws {
        let image = try render([
            Line("Second line here", x: 60, top: 300, size: 48),
            Line("First line here", x: 60, top: 100, size: 48),
        ])
        let blocks = try await VisionTextRecognizer().recognize(image, mode: .fast, languages: ["en-US", "xx"])
        #expect(blocks.map { $0.text.lowercased() } == ["first line here", "second line here"])
    }

    @Test func emptyImagesHaveNoBlocks() async throws {
        let blocks = try await VisionTextRecognizer().recognize(render([]), mode: .fast, languages: [])
        #expect(blocks.isEmpty)
    }

    @Test func languageHintsMatchSupportedLanguagesByCodeAndScript() {
        let supported = ["en-US", "fr-FR", "zh-Hans-CN", "zh-Hant-TW", "ja-JP"].map(Locale.Language.init(identifier:))
        let hints = ["ja", "zh-Hant", "en-GB", "xx", "ja"].map(Locale.Language.init(identifier:))
        let matched = VisionTextRecognizer.matching(hints, in: supported).map(\.maximalIdentifier)
        #expect(matched == ["ja-Jpan-JP", "zh-Hant-TW", "en-Latn-US"])
    }
}
