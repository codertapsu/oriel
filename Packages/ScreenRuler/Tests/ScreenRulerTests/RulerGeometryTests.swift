import CoreGraphics
import OrielCore
@testable import ScreenRuler
import Testing

/// Three displays as AppKit reports them: a 2× primary, a 1× display above and to the right (so negative y in
/// CoreGraphics), and one to the left (negative x).
struct RulerGeometryTests {
    private let primaryHeight: CGFloat = 900
    private var primary: RulerDisplay {
        RulerDisplay(id: 1, cocoaFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), primaryHeight: primaryHeight, scale: 2)
    }

    private var upperRight: RulerDisplay {
        RulerDisplay(id: 2, cocoaFrame: CGRect(x: 1440, y: 300, width: 1920, height: 1080), primaryHeight: primaryHeight, scale: 1)
    }

    private var left: RulerDisplay {
        RulerDisplay(id: 3, cocoaFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800), primaryHeight: primaryHeight, scale: 1)
    }

    @Test func displaysAreFlippedIntoGlobalCoreGraphicsPoints() {
        #expect(primary.frame == CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect(upperRight.frame == CGRect(x: 1440, y: -480, width: 1920, height: 1080))
        #expect(left.frame == CGRect(x: -1280, y: 100, width: 1280, height: 800))
        #expect(primary.pixelWidth == 2880 && primary.pixelHeight == 1800)
        let displays = [primary, upperRight, left]
        #expect(RulerDisplay.display(at: CGPoint(x: 2000, y: -100), among: displays)?.id == 2)
        #expect(RulerDisplay.display(at: CGPoint(x: -10, y: 500), among: displays)?.id == 3)
        #expect(RulerDisplay.display(at: CGPoint(x: -10, y: 50), among: displays) == nil, "above the left display")
    }

    @Test func pointsAndPixelsConvertBothWays() {
        let pixel = primary.pixel(at: CGPoint(x: 100.75, y: 50.25))
        #expect(pixel == (201, 100))
        #expect(primary.globalX(column: 201) == 100.5)
        #expect(primary.globalY(row: 100) == 50)
        #expect(upperRight.pixel(at: CGPoint(x: 1441.5, y: -479.5)) == (1, 0))
        #expect(upperRight.globalRect(PixelRect(minX: 10, minY: 20, maxX: 30, maxY: 60)) == CGRect(x: 1450, y: -460, width: 20, height: 40))
        #expect(left.pixel(at: CGPoint(x: -5000, y: 99999)) == (0, 799), "clamped to the display")
    }

    @Test func pointsSnapToWholePointsOrPixels() {
        #expect(primary.snapped(CGPoint(x: 10.3, y: 20.8), to: .points) == CGPoint(x: 10, y: 21))
        #expect(primary.snapped(CGPoint(x: 10.3, y: 20.8), to: .pixels) == CGPoint(x: 10.5, y: 21))
        #expect(upperRight.snapped(CGPoint(x: 1500.4, y: -300.6), to: .pixels) == CGPoint(x: 1500, y: -301))
        #expect(primary.snapped(CGPoint(x: -3, y: 2000), to: .points) == CGPoint(x: 0, y: 900), "kept on the display")
    }

    @Test func overlayViewsHaveTheirOriginAtTheDisplaysBottomLeft() {
        for display in [primary, upperRight, left] {
            let mapping = RulerViewMapping(display: display)
            let topLeft = CGPoint(x: display.frame.minX, y: display.frame.minY)
            #expect(mapping.viewPoint(topLeft) == CGPoint(x: 0, y: display.frame.height))
            let inside = CGPoint(x: display.frame.minX + 30, y: display.frame.minY + 40)
            #expect(mapping.globalPoint(mapping.viewPoint(inside)) == inside)
            let rect = CGRect(x: display.frame.minX + 10, y: display.frame.minY + 20, width: 100, height: 50)
            #expect(mapping.viewRect(rect) == CGRect(x: 10, y: display.frame.height - 70, width: 100, height: 50))
            #expect(mapping.viewX(display.frame.maxX) == display.frame.width && mapping.viewY(display.frame.maxY) == 0)
        }
    }

    @Test(arguments: [
        (CGFloat(320), RulerUnit.points, CGFloat(2), "320"),
        (320.5, .points, 2, "320.5"),
        (160.25, .pixels, 2, "320.5"),
        (160, .pixels, 2, "320"),
        (99.96, .points, 1, "100"),
        (-12, .points, 1, "-12"),
        (0.04, .points, 1, "0"),
    ])
    func lengthsAreWholeWhereTheyAreWhole(_ points: CGFloat, _ unit: RulerUnit, _ scale: CGFloat, _ expected: String) {
        #expect(RulerFormat.number(points, unit: unit, scale: scale) == expected)
    }

    @Test func measurementsReadAsTheyAreCopied() {
        #expect(RulerFormat.size(CGSize(width: 320, height: 240), unit: .points, scale: 2) == "320 × 240 pt")
        #expect(RulerFormat.size(CGSize(width: 320, height: 240), unit: .pixels, scale: 2) == "640 × 480 px")
        #expect(RulerFormat.otherSize(CGSize(width: 320, height: 240), unit: .points, scale: 2) == "640 × 480 px")
        #expect(RulerFormat.length(12.5, unit: .points, scale: 2) == "12.5 pt")
        #expect(RulerFormat.position(CGPoint(x: 1560, y: -432), on: upperRight, unit: .points) == "x 120  y 48")
        #expect(RulerFormat.position(CGPoint(x: 60, y: 24.5), on: primary, unit: .pixels) == "x 120  y 49")
    }
}
