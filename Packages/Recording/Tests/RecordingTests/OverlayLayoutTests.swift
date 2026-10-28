import CoreGraphics
@testable import Recording
import Testing

struct OverlayLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    /// The visible frame without the menu bar.
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 945)
    private let bar = CGSize(width: 220, height: 40)

    @Test func putsTheControlBarBelowARegionWhenThereIsRoom() {
        let region = CGRect(x: 400, y: 300, width: 600, height: 400)
        let frame = OverlayLayout.controlBarFrame(size: bar, captureRect: region, visibleFrame: visible)
        #expect(frame.maxY == region.minY - OverlayLayout.margin)
        #expect(frame.midX == region.midX)
    }

    @Test func putsItAboveWhenTheRegionReachesTheBottom() {
        let region = CGRect(x: 400, y: 0, width: 600, height: 400)
        let frame = OverlayLayout.controlBarFrame(size: bar, captureRect: region, visibleFrame: visible)
        #expect(frame.minY == region.maxY + OverlayLayout.margin)
    }

    @Test func putsItInsideAFullScreenRecording() {
        let frame = OverlayLayout.controlBarFrame(size: bar, captureRect: screen, visibleFrame: visible)
        #expect(visible.contains(frame))
        #expect(frame.minY == 2 * OverlayLayout.margin)
        #expect(frame.midX == screen.midX)
    }

    @Test func keepsTheControlBarOnScreenForRegionsAtTheEdge() {
        let region = CGRect(x: 1400, y: 500, width: 112, height: 200)
        let frame = OverlayLayout.controlBarFrame(size: bar, captureRect: region, visibleFrame: visible)
        #expect(frame.maxX == visible.maxX - OverlayLayout.margin)
    }

    @Test func putsTheCameraBubbleInTheBottomLeftCorner() {
        let frame = OverlayLayout.cameraBubbleFrame(captureRect: screen)
        #expect(frame.size == CGSize(width: OverlayLayout.cameraDiameter, height: OverlayLayout.cameraDiameter))
        #expect(frame.origin == CGPoint(x: 24, y: 24))
        let small = OverlayLayout.cameraBubbleFrame(captureRect: CGRect(x: 100, y: 100, width: 300, height: 240))
        #expect(small.width == 80)
        #expect(CGRect(x: 100, y: 100, width: 300, height: 240).contains(small))
    }

    @Test func centresTheKeystrokeHUDNearTheBottom() {
        let frame = OverlayLayout.keystrokeFrame(size: CGSize(width: 200, height: 50), captureRect: screen)
        #expect(frame.midX == screen.midX)
        #expect(frame.minY == 72)
    }
}
