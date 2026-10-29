@testable import Editor
import Testing

/// The fill behind lifted objects and erased text (PLAN §17), on synthetic images: flat backgrounds come back
/// exactly, linear gradients as gradients, objects disappear, and holes at the image's edge still fill.
struct HoleFillerTests {
    private func image(width: Int, height: Int, _ color: (Int, Int) -> PixelColor) -> PixelImage {
        var image = PixelImage(width: width, height: height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                image[x, y] = color(x, y)
            }
        }
        return image
    }

    private func maximumError(in image: PixelImage, hole: PixelRect, expected: (Int, Int) -> PixelColor) -> Int {
        var worst = 0
        for y in hole.y ..< hole.maxY {
            for x in hole.x ..< hole.maxX {
                worst = max(worst, image[x, y].distance(to: expected(x, y)))
            }
        }
        return worst
    }

    @Test func aFlatBackgroundComesBackExactlyAndTheObjectIsGone() {
        let background = PixelColor(red: 200, green: 100, blue: 50)
        var picture = image(width: 40, height: 30) { x, y in
            (10 ..< 20).contains(x) && (8 ..< 18).contains(y) ? PixelColor(red: 0, green: 0, blue: 0) : background
        }
        let hole = PixelRect(x: 9, y: 7, width: 13, height: 13)
        HoleFiller.fill(&picture, hole: hole)
        #expect(maximumError(in: picture, hole: hole) { _, _ in background } == 0)
        // Outside the hole nothing changed.
        #expect(picture[2, 2] == background && picture[39, 29] == background)
    }

    @Test func aHorizontalGradientComesBackAsAGradient() {
        let gradient: (Int, Int) -> PixelColor = { x, _ in PixelColor(red: UInt8(x * 6), green: 100, blue: 20) }
        var picture = image(width: 40, height: 30, gradient)
        let hole = PixelRect(x: 10, y: 5, width: 15, height: 10)
        for y in hole.y ..< hole.maxY {
            for x in hole.x ..< hole.maxX {
                picture[x, y] = PixelColor(red: 255, green: 255, blue: 255)
            }
        }
        HoleFiller.fill(&picture, hole: hole)
        #expect(maximumError(in: picture, hole: hole, expected: gradient) <= 1)
    }

    @Test func verticalAndDiagonalGradientsComeBackToo() {
        let vertical: (Int, Int) -> PixelColor = { _, y in PixelColor(red: 30, green: 60, blue: UInt8(y * 7)) }
        var first = image(width: 30, height: 36, vertical)
        let hole = PixelRect(x: 6, y: 8, width: 16, height: 18)
        HoleFiller.fill(&first, hole: hole)
        #expect(maximumError(in: first, hole: hole, expected: vertical) <= 1)

        let diagonal: (Int, Int) -> PixelColor = { x, y in PixelColor(red: UInt8(x * 3 + y * 2), green: 90, blue: 200) }
        var second = image(width: 50, height: 40, diagonal)
        HoleFiller.fill(&second, hole: hole)
        #expect(maximumError(in: second, hole: hole, expected: diagonal) <= 1)
    }

    @Test func aHoleAtTheEdgeFillsFromTheSidesItHas() {
        let background = PixelColor(red: 20, green: 120, blue: 220)
        var picture = image(width: 30, height: 20) { x, y in
            x < 6 && (5 ..< 12).contains(y) ? PixelColor(red: 255, green: 0, blue: 0) : background
        }
        let hole = PixelRect(x: 0, y: 4, width: 8, height: 10)
        HoleFiller.fill(&picture, hole: hole)
        #expect(maximumError(in: picture, hole: hole) { _, _ in background } == 0)
    }

    @Test func aHoleOverTheWholeImageIsLeftAlone() {
        let original = image(width: 8, height: 8) { x, _ in PixelColor(red: UInt8(x * 30), green: 0, blue: 0) }
        var picture = original
        HoleFiller.fill(&picture, hole: PixelRect(x: 0, y: 0, width: 8, height: 8))
        #expect(picture == original)
    }

    @Test func noiseAtTheHolesEdgeDoesNotStreak() {
        let background = PixelColor(red: 240, green: 240, blue: 240)
        // A flat panel with a few anti-aliased pixels of text touching the hole's top edge.
        var picture = image(width: 40, height: 30) { x, y in
            y == 6 && x % 7 == 0 ? PixelColor(red: 90, green: 90, blue: 90) : background
        }
        let hole = PixelRect(x: 5, y: 7, width: 30, height: 12)
        HoleFiller.fill(&picture, hole: hole)
        #expect(maximumError(in: picture, hole: hole) { _, _ in background } <= 12)
    }
}
