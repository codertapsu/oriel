import CoreGraphics
import Foundation
@testable import OCR
import OrielCore
import Testing

/// Runs real Vision recognition on images drawn in memory. Vision needs no permission and shows nothing.
struct VisionTextRecognizerTests {
    private typealias Line = TextImage.Line

    private func render(_ lines: [Line], width: Int = 1200, height: Int = 600) throws -> CGImage {
        try TextImage.render(lines, width: width, height: height)
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
