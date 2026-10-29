import CoreGraphics
@testable import OrielTranslation
import Testing

struct CursorGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func capturesAroundThePointerAndStaysOnTheScreen() {
        #expect(CursorGeometry.captureRect(around: CGPoint(x: 700, y: 400), on: screen) == CGRect(x: 400, y: 340, width: 600, height: 120))
        #expect(CursorGeometry.captureRect(around: CGPoint(x: 10, y: 5), on: screen) == CGRect(x: 0, y: 0, width: 600, height: 120))
        #expect(CursorGeometry.captureRect(around: CGPoint(x: 1435, y: 895), on: screen) == CGRect(x: 840, y: 780, width: 600, height: 120))
        // A second display to the left, with negative coordinates.
        let left = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        #expect(CursorGeometry.captureRect(around: CGPoint(x: -5, y: 100), on: left) == CGRect(x: -600, y: 40, width: 600, height: 120))
    }

    @Test func theTooltipGoesBelowTheTextElseAboveIt() {
        let size = CGSize(width: 300, height: 80)
        let region = CGRect(x: 200, y: 300, width: 400, height: 40)
        let below = CursorGeometry.tooltipFrame(size: size, region: region, pointer: CGPoint(x: 260, y: 320), visible: screen)
        #expect(below == CGRect(x: 236, y: 348, width: 300, height: 80))
        let low = CGRect(x: 200, y: 840, width: 400, height: 40)
        let above = CursorGeometry.tooltipFrame(size: size, region: low, pointer: CGPoint(x: 260, y: 860), visible: screen)
        #expect(above == CGRect(x: 236, y: 752, width: 300, height: 80))
        // Near the right edge it moves left to stay on the screen.
        let right = CursorGeometry.tooltipFrame(size: size, region: region, pointer: CGPoint(x: 1430, y: 320), visible: screen)
        #expect(right.maxX == screen.maxX - CursorGeometry.gap)
        // Text that fills the screen: next to the pointer, on the screen.
        let full = CursorGeometry.tooltipFrame(size: size, region: screen, pointer: CGPoint(x: 700, y: 450), visible: screen)
        #expect(screen.contains(full) && full.minY == 474)
    }
}
