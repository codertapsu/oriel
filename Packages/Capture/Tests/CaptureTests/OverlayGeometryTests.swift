@testable import Capture
import CoreGraphics
import Testing

struct OverlayGeometryTests {
    /// The external display of the dev Mac's layout: right of the primary, 458 points higher.
    private let external = OverlayGeometry(displayFrame: CGRect(x: 1512, y: -458, width: 2560, height: 1440), scale: 1)
    private let retina = OverlayGeometry(displayFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)

    @Test func viewCoordinatesAreFlippedAndLocal() {
        #expect(external.viewPoint(CGPoint(x: 1600, y: -400)) == CGPoint(x: 88, y: 1382))
        #expect(external.globalPoint(CGPoint(x: 88, y: 1382)) == CGPoint(x: 1600, y: -400))
        // The display's top-left corner is the view's top-left, at y = height.
        #expect(external.viewPoint(CGPoint(x: 1512, y: -458)) == CGPoint(x: 0, y: 1440))
        #expect(retina.viewRect(CGRect(x: 10, y: 20, width: 100, height: 50)) == CGRect(x: 10, y: 912, width: 100, height: 50))
    }

    @Test func roundTripsAreExact() {
        for point in [CGPoint(x: 1512, y: -458), CGPoint(x: 2000.5, y: 0.25), CGPoint(x: 4071, y: 981)] {
            #expect(external.globalPoint(external.viewPoint(point)) == point)
        }
    }

    @Test func pixelsUnderThePointerScaleAndClamp() {
        #expect(retina.pixel(at: CGPoint(x: 10.25, y: 20.75)) == (20, 41))
        #expect(retina.pixel(at: CGPoint(x: -5, y: 2000)) == (0, 1963))
        #expect(external.pixel(at: CGPoint(x: 1513, y: -457)) == (1, 1))
    }
}
