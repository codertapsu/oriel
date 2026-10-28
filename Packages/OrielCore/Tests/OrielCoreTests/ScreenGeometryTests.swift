import CoreGraphics
import OrielCore
import Testing

struct ScreenGeometryTests {
    @Test func flippingTwiceIsIdentity() {
        let rect = CGRect(x: 100, y: 200, width: 300, height: 50)
        let flipped = ScreenGeometry.cgRect(fromCocoa: rect, primaryHeight: 982)
        #expect(flipped == CGRect(x: 100, y: 732, width: 300, height: 50))
        #expect(ScreenGeometry.cocoaRect(fromCG: flipped, primaryHeight: 982) == rect)
    }

    @Test func displaysAboveAndLeftOfThePrimaryHaveNegativeOrigins() {
        // A 1080-pt display to the left whose top edge is 98 pt above the 982-pt primary (as on the dev Mac).
        let leftInCocoa = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        #expect(ScreenGeometry.cgRect(fromCocoa: leftInCocoa, primaryHeight: 982) == CGRect(x: -1920, y: -98, width: 1920, height: 1080))
    }

    @Test(arguments: [
        (CGRect(x: 10, y: 10, width: 100, height: 50), CGFloat(2), CGRect(x: 20, y: 20, width: 200, height: 100)),
        (CGRect(x: 0.25, y: 0, width: 10, height: 10), CGFloat(2), CGRect(x: 0, y: 0, width: 21, height: 20)),
        (CGRect(x: 10, y: 10, width: 100, height: 50), CGFloat(1), CGRect(x: 10, y: 10, width: 100, height: 50)),
    ])
    func pixelRectScalesAndKeepsPartialPixels(points: CGRect, scale: CGFloat, expected: CGRect) {
        let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(ScreenGeometry.pixelRect(for: points, displayBounds: display, scale: scale) == expected)
    }

    @Test func pixelRectIsRelativeToItsDisplayAndClipped() {
        let display = CGRect(x: 1512, y: -458, width: 2560, height: 1440)
        let selection = CGRect(x: 1500, y: -458, width: 100, height: 100)
        #expect(ScreenGeometry.pixelRect(for: selection, displayBounds: display, scale: 1) == CGRect(x: 0, y: 0, width: 88, height: 100))
        #expect(ScreenGeometry.pixelRect(for: CGRect(x: 0, y: 0, width: 10, height: 10), displayBounds: display, scale: 1) == .zero)
    }

    @Test func dragRectIsOrderIndependent() {
        let rect = ScreenGeometry.rect(from: CGPoint(x: 50, y: 80), to: CGPoint(x: 10, y: 20))
        #expect(rect == CGRect(x: 10, y: 20, width: 40, height: 60))
    }

    @Test func bestDisplayIsTheOneWithTheLargestOverlap() {
        let displays = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)]
        #expect(ScreenGeometry.bestDisplay(for: CGRect(x: 80, y: 0, width: 50, height: 10), among: displays) == 1)
        #expect(ScreenGeometry.bestDisplay(for: CGRect(x: 500, y: 500, width: 1, height: 1), among: displays) == 0)
    }
}
