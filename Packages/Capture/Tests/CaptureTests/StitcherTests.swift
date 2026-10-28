@testable import Capture
import CoreGraphics
import Testing

/// PLAN §13.3: "Stitcher output correct on synthetic sequences (sticky header, repeated rows, end detection)".
struct StitcherTests {
    private let page = SyntheticPage(width: 96, height: 1600, seed: 7)
    private let viewport = 240
    private let step = 100

    @Test func plainPagesStitchExactly() {
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        for position in stride(from: step, through: 1300, by: step) {
            #expect(stitcher.add(page.viewport(at: position, height: viewport), expectedOffset: step) == .appended(offset: step))
        }
        #expect(stitcher.length == 1540)
        #expect(stitcher.finish() == page.frame(0 ..< 1540))
    }

    @Test func manualModeFindsTheOffsetWithoutBeingTold() {
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        #expect(stitcher.add(page.viewport(at: 37, height: viewport), expectedOffset: nil) == .appended(offset: 37))
        #expect(stitcher.add(page.viewport(at: 150, height: viewport), expectedOffset: nil) == .appended(offset: 113))
        #expect(stitcher.finish() == page.frame(0 ..< 390))
    }

    @Test func stickyHeaderAndFooterAreDrawnOnce() {
        let chrome = SyntheticPage(width: 96, height: 40, seed: 99)
        let header = Array(chrome.rows[0 ..< 24])
        let footer = Array(chrome.rows[24 ..< 40])
        let body = 200
        func frame(at position: Int) -> PixelFrame {
            SyntheticPage.frame(header + Array(page.rows[position ..< position + body]) + footer)
        }
        var stitcher = ScrollStitcher(first: frame(at: 0))
        for position in stride(from: step, through: 1000, by: step) {
            #expect(stitcher.add(frame(at: position), expectedOffset: step) == .appended(offset: step))
        }
        let expected = SyntheticPage.frame(header + Array(page.rows[0 ..< 1000 + body]) + footer)
        #expect(stitcher.finish() == expected)
    }

    @Test func repeatedRowsNeedTheExpectedOffset() {
        let table = SyntheticPage(width: 96, height: 1600, seed: 11, repeating: 400 ..< 1000)
        let first = table.viewport(at: 500, height: viewport)
        let next = table.viewport(at: 600, height: viewport)
        // Without a hint every multiple of the 40-row period matches equally well.
        var manual = ScrollStitcher(first: first)
        #expect(manual.add(next, expectedOffset: nil) == .lowConfidence)
        // ±25 % around the scroll that was asked for leaves only the right one, even when the app scrolled less.
        var auto = ScrollStitcher(first: first)
        #expect(auto.add(next, expectedOffset: 100) == .appended(offset: 100))
        var short = ScrollStitcher(first: first)
        #expect(short.add(next, expectedOffset: 110) == .appended(offset: 100))
        #expect(short.finish() == table.frame(500 ..< 840))
    }

    @Test func anUnchangedFrameEndsTheCapture() {
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        #expect(stitcher.add(page.viewport(at: 100, height: viewport), expectedOffset: step) == .appended(offset: step))
        #expect(stitcher.add(page.viewport(at: 100, height: viewport), expectedOffset: step) == .endReached)
        // An overlay scrollbar that appeared in the masked columns does not count as movement.
        var withScrollbar = page.viewport(at: 100, height: viewport).pixels
        for row in 0 ..< viewport {
            for column in 90 ..< 96 {
                let index = (row * 96 + column) * 4
                withScrollbar.replaceSubrange(index ..< index + 3, with: [40, 40, 40])
            }
        }
        let scrolled = PixelFrame(width: 96, height: viewport, pixels: withScrollbar)
        #expect(stitcher.add(scrolled, expectedOffset: step) == .endReached)
        #expect(stitcher.finish() == page.frame(0 ..< 340))
    }

    @Test func theLastShortScrollIsFound() {
        var stitcher = ScrollStitcher(first: page.viewport(at: 1200, height: viewport))
        #expect(stitcher.add(page.viewport(at: 1300, height: viewport), expectedOffset: step) == .appended(offset: 100))
        #expect(stitcher.add(page.viewport(at: 1360, height: viewport), expectedOffset: step) == .appended(offset: 60))
        #expect(stitcher.add(page.viewport(at: 1360, height: viewport), expectedOffset: step) == .endReached)
        #expect(stitcher.finish() == page.frame(1200 ..< 1600))
    }

    @Test func unrelatedFramesAreRejected() {
        let other = SyntheticPage(width: 96, height: 400, seed: 1234)
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        #expect(stitcher.add(other.viewport(at: 0, height: viewport), expectedOffset: step) == .lowConfidence)
        #expect(stitcher.add(other.viewport(at: 0, height: viewport), expectedOffset: nil) == .lowConfidence)
        #expect(stitcher.add(page.viewport(at: 0, height: 120), expectedOffset: step) == .lowConfidence)
        // A rejected frame leaves the result as it was.
        #expect(stitcher.add(page.viewport(at: 100, height: viewport), expectedOffset: step) == .appended(offset: step))
        #expect(stitcher.finish() == page.frame(0 ..< 340))
    }

    @Test func theResultStopsAtTheMaximumLength() {
        var configuration = ScrollStitcher.Configuration()
        configuration.maxLength = 500
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport), configuration: configuration)
        #expect(stitcher.add(page.viewport(at: 100, height: viewport), expectedOffset: step) == .appended(offset: step))
        #expect(stitcher.add(page.viewport(at: 200, height: viewport), expectedOffset: step) == .appended(offset: step))
        #expect(stitcher.add(page.viewport(at: 300, height: viewport), expectedOffset: step) == .limitReached)
        #expect(stitcher.add(page.viewport(at: 400, height: viewport), expectedOffset: step) == .limitReached)
        #expect(stitcher.finish() == page.frame(0 ..< 500))
    }

    @Test func horizontalScrollingIsTheTranspose() {
        var vertical = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        var horizontal = ScrollStitcher(first: page.viewport(at: 0, height: viewport).transposed(), direction: .horizontal)
        for position in [100, 200, 260] {
            let frame = page.viewport(at: position, height: viewport)
            let expected = vertical.add(frame, expectedOffset: step)
            #expect(horizontal.add(frame.transposed(), expectedOffset: step) == expected)
        }
        let wide = horizontal.finish()
        #expect(wide.width == 500 && wide.height == 96)
        #expect(wide == vertical.finish().transposed())
    }

    @Test func framesRoundTripThroughImages() throws {
        let frame = page.viewport(at: 0, height: 50)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try #require(frame.makeImage(colorSpace: space))
        #expect(image.width == 96 && image.height == 50)
        #expect(PixelFrame(image: image, colorSpace: space) == frame)
        #expect(frame.transposed().transposed() == frame)
    }
}
