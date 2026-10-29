import CoreGraphics
@testable import ScreenRuler
import Testing

struct EdgeMapTests {
    /// A 400 × 300 white picture with a black block over columns 100 ..< 300 and rows 50 ..< 150.
    private func block() -> EdgeMap {
        var bitmap = SyntheticBitmap(width: 400, height: 300)
        bitmap.fill(x: 100, y: 50, width: 200, height: 100, gray: 0)
        return bitmap.map
    }

    @Test func aSolidBlockHasItsEdgesExactly() {
        let map = block()
        #expect(map.horizontalSpan(row: 100, column: 150, tolerance: 10) == (100, 300))
        #expect(map.verticalSpan(column: 150, row: 100, tolerance: 10) == (50, 150))
        // Outside the block the span reaches the block, or the display's edge.
        #expect(map.horizontalSpan(row: 100, column: 20, tolerance: 10) == (0, 100))
        #expect(map.horizontalSpan(row: 100, column: 350, tolerance: 10) == (300, 400))
        #expect(map.verticalSpan(column: 150, row: 10, tolerance: 10) == (0, 50))
        #expect(map.verticalSpan(column: 20, row: 10, tolerance: 10) == (0, 300))
        // The block's first and last pixels belong to it.
        #expect(map.horizontalSpan(row: 50, column: 100, tolerance: 10) == (100, 300))
        #expect(map.horizontalSpan(row: 149, column: 299, tolerance: 10) == (100, 300))
    }

    @Test func aColorChangeBelowTheToleranceIsNoEdge() {
        var bitmap = SyntheticBitmap(width: 200, height: 10, gray: 200)
        bitmap.fill(x: 50, y: 0, width: 100, height: 10, gray: 190)
        #expect(bitmap.map.horizontalSpan(row: 5, column: 100, tolerance: 12) == (0, 200))
        #expect(bitmap.map.horizontalSpan(row: 5, column: 100, tolerance: 9) == (50, 150))
        // Any channel counts: a red-only change of 40 is an edge.
        var colored = SyntheticBitmap(width: 200, height: 10, gray: 100)
        colored.fill(x: 50, y: 0, width: 100, height: 10, red: 140, green: 100, blue: 100)
        #expect(colored.map.horizontalSpan(row: 5, column: 100, tolerance: 30) == (50, 150))
    }

    /// A gradient's small steps are not edges, so the span runs across it to the block.
    @Test func aGradientIsNotAnEdge() {
        var bitmap = SyntheticBitmap.gradient(width: 1000, height: 20, from: 0, to: 255)
        bitmap.fill(x: 600, y: 0, width: 100, height: 20, red: 255, green: 0, blue: 0)
        let map = bitmap.map
        #expect(map.horizontalSpan(row: 10, column: 100, tolerance: 5) == (0, 600))
        #expect(map.horizontalSpan(row: 10, column: 650, tolerance: 5) == (600, 700))
        // A steep ramp, one step of 50 per pixel, is edges all the way.
        let steep = SyntheticBitmap.gradient(width: 6, height: 1, from: 0, to: 250).map
        #expect(steep.horizontalSpan(row: 0, column: 3, tolerance: 20) == (3, 4))
    }

    /// Noise below the tolerance is ignored; a tolerance below the noise finds false edges at once.
    @Test func noiseBelowTheToleranceIsIgnored() {
        var bitmap = SyntheticBitmap.noise(width: 300, height: 120, gray: 128, amplitude: 4)
        bitmap.fill(x: 120, y: 40, width: 60, height: 40, gray: 30)
        let map = bitmap.map
        #expect(map.horizontalSpan(row: 60, column: 150, tolerance: 12) == (120, 180))
        #expect(map.horizontalSpan(row: 60, column: 40, tolerance: 12) == (0, 120))
        #expect(map.verticalSpan(column: 40, row: 60, tolerance: 12) == (0, 120))
        let fooled = map.horizontalSpan(row: 60, column: 40, tolerance: 2)
        #expect(fooled.end - fooled.start < 60)
    }

    /// On a Retina display two pixels make a point, so an edge between pixels lands on a half point.
    @Test func retinaEdgesAreMeasuredInPointsAndPixels() {
        var bitmap = SyntheticBitmap(width: 800, height: 600)
        bitmap.fill(x: 101, y: 40, width: 200, height: 61, gray: 0)
        let display = RulerDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)
        let measurement = DimensionsMeasurement(at: CGPoint(x: 100, y: 50), on: display, in: bitmap.map, tolerance: 10)
        #expect(measurement.box == PixelRect(minX: 101, minY: 40, maxX: 301, maxY: 101))
        #expect(measurement.rect == CGRect(x: 50.5, y: 20, width: 100, height: 30.5))
        #expect(measurement.text(unit: .points) == "100 × 30.5 pt")
        #expect(measurement.text(unit: .pixels) == "200 × 61 px")
        #expect(measurement.left == 49.5 && measurement.right == 50.5)
        #expect(measurement.up == 30 && measurement.down == 0.5)
    }

    @Test func aBoxDrawnAroundSomethingShrinksToIt() throws {
        let map = block()
        #expect(map.contentBounds(in: PixelRect(minX: 60, minY: 20, maxX: 380, maxY: 200), tolerance: 10)
            == PixelRect(minX: 100, minY: 50, maxX: 300, maxY: 150))
        // Started inside the block, the box keeps the block's part that it covers.
        #expect(map.contentBounds(in: PixelRect(minX: 150, minY: 20, maxX: 380, maxY: 200), tolerance: 10)
            == PixelRect(minX: 150, minY: 50, maxX: 300, maxY: 150))
        // Nothing changes color in an empty corner.
        #expect(map.contentBounds(in: PixelRect(minX: 0, minY: 200, maxX: 90, maxY: 300), tolerance: 10) == nil)
        // On a gradient the block's edges still decide.
        var gradient = SyntheticBitmap.gradient(width: 500, height: 200, from: 30, to: 220)
        gradient.fill(x: 200, y: 60, width: 50, height: 70, red: 0, green: 120, blue: 255)
        let fitted = try #require(gradient.map.contentBounds(in: PixelRect(minX: 10, minY: 10, maxX: 490, maxY: 190), tolerance: 6))
        #expect(fitted == PixelRect(minX: 200, minY: 60, maxX: 250, maxY: 130))
    }

    @Test func aGlyphLikeShapeFitsItsOutermostPixels() {
        var bitmap = SyntheticBitmap(width: 100, height: 100)
        bitmap.fill(x: 30, y: 20, width: 3, height: 40, gray: 0)
        bitmap.fill(x: 30, y: 20, width: 25, height: 3, gray: 0)
        bitmap.fill(x: 52, y: 58, width: 2, height: 2, gray: 90)
        #expect(bitmap.map.contentBounds(in: PixelRect(minX: 0, minY: 0, maxX: 100, maxY: 100), tolerance: 10)
            == PixelRect(minX: 30, minY: 20, maxX: 55, maxY: 60))
    }

    @Test func snappingFindsTheNearestEdgeWithinReach() {
        let map = block()
        #expect(map.nearestColumnEdge(row: 100, near: 96, within: 6, tolerance: 10) == 100)
        #expect(map.nearestColumnEdge(row: 100, near: 305, within: 6, tolerance: 10) == 300)
        #expect(map.nearestColumnEdge(row: 100, near: 90, within: 6, tolerance: 10) == nil)
        #expect(map.nearestColumnEdge(row: 10, near: 100, within: 6, tolerance: 10) == nil, "the block is not on that row")
        #expect(map.nearestRowEdge(column: 200, near: 147, within: 5, tolerance: 10) == 150)
        #expect(map.nearestRowEdge(column: 200, near: 4, within: 5, tolerance: 10) == nil)
    }
}
