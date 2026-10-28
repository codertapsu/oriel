import CoreGraphics
@testable import OrielTranslation
import Testing

struct FontFitTests {
    /// A fixed-seed generator, so a failing case reproduces.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private static let words = [
        "Settings", "Übersetzung", "翻訳", "the", "a", "translation", "réglages", "مرحبا", "supercalifragilisticexpialidocious",
        "OK", "—", "1,234.56", "https://example.com/a/very/long/path", "设置", "Einstellungen", "\n",
    ]

    @Test func neverOverflowsItsBoxAtOrAboveTheMinimumSize() {
        var generator = SeededGenerator(state: 0x5EED)
        for _ in 0 ..< 300 {
            let text = (0 ..< Int.random(in: 1 ... 40, using: &generator))
                .map { _ in Self.words.randomElement(using: &generator) ?? "x" }
                .joined(separator: " ")
            let box = CGSize(width: .random(in: 20 ... 400, using: &generator), height: .random(in: 8 ... 160, using: &generator))
            let maximum = CGFloat.random(in: 4 ... 40, using: &generator)
            let rightToLeft = Bool.random(using: &generator)
            let fit = FontFitter.fit(text, in: box, maximumSize: maximum, rightToLeft: rightToLeft)
            #expect(fit.fontSize >= FontFitter.minimumSize && fit.fontSize <= max(FontFitter.minimumSize, maximum))
            let measured = FontFitter.measure(text, fontSize: fit.fontSize, width: box.width, rightToLeft: rightToLeft)
            if fit.fits {
                #expect(
                    measured.height <= box.height + 0.5 && measured.width <= box.width + 0.5,
                    "“\(text)” in \(box) at \(fit.fontSize) pt"
                )
            } else {
                #expect(fit.fontSize == FontFitter.minimumSize)
                #expect(measured.height > box.height + 0.5 || measured.width > box.width + 0.5)
            }
        }
    }

    @Test func usesTheOriginalLineHeightWhenTheTranslationFitsAtIt() {
        let fit = FontFitter.fit("OK", in: CGSize(width: 300, height: 40), maximumSize: 18)
        #expect(fit.fits && fit.fontSize == 18)
    }

    @Test func shrinksALongTranslationBelowTheLineHeight() {
        let text = "This translation is considerably longer than the original label it replaces"
        let fit = FontFitter.fit(text, in: CGSize(width: 160, height: 40), maximumSize: 18)
        #expect(fit.fits && fit.fontSize < 18 && fit.fontSize >= FontFitter.minimumSize)
        // A quarter point more no longer fits: the search found (almost) the largest size.
        let bigger = FontFitter.measure(text, fontSize: fit.fontSize + 0.5, width: 160)
        #expect(bigger.height > 40.5)
    }

    @Test func reportsOverflowWhenEvenTheMinimumSizeIsTooBig() {
        let text = String(repeating: "Far too much text for this box. ", count: 20)
        let fit = FontFitter.fit(text, in: CGSize(width: 80, height: 12), maximumSize: 12)
        #expect(!fit.fits && fit.fontSize == FontFitter.minimumSize && fit.textSize.height > 12)
    }

    @Test func blocksGrowDownwardOnlyWhenTheirTextDoesNotFit() {
        let colors = BlockColors(background: .white, text: .black)
        let line = CGRect(x: 20, y: 40, width: 120, height: 32) // 16 pt tall on screen
        let fitted = OverlayBlockLayout.make(
            id: 1,
            text: "Hi",
            box: line,
            lineCount: 1,
            pointsPerPixel: 0.5,
            colors: colors,
            rightToLeft: false
        )
        #expect(fitted.frame == CGRect(x: 10, y: 20, width: 60, height: 16) && !fitted.isExpanded)
        #expect(fitted.fontSize > FontFitter.minimumSize && fitted.fontSize <= 16)

        let box = CGRect(x: 20, y: 40, width: 120, height: 16) // 8 pt: too small even for 6 pt text
        let long = String(repeating: "Much longer translated text. ", count: 6)
        let grown = OverlayBlockLayout.make(
            id: 2,
            text: long,
            box: box,
            lineCount: 1,
            pointsPerPixel: 0.5,
            colors: colors,
            rightToLeft: false
        )
        #expect(grown.isExpanded && grown.fontSize == FontFitter.minimumSize)
        #expect(grown.frame.minX == 10 && grown.frame.minY == 20 && grown.frame.width == 60 && grown.frame.height > 8)
        let measured = FontFitter.measure(long, fontSize: grown.fontSize, width: grown.textRect.width)
        #expect(measured.height <= grown.textRect.height + 0.5)
    }
}
