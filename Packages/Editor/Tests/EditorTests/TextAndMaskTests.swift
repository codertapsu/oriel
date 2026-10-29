import CoreGraphics
@testable import Editor
import Testing

/// The colours Simplify reads from a line of text, the masks Smart Move cuts objects with, and how lines group into
/// blocks.
struct TextAndMaskTests {
    @Test func inkIsTheTextsColourAndTheBackgroundTheEdgesColour() throws {
        var line = PixelImage(width: 60, height: 20, fill: PixelColor(red: 255, green: 255, blue: 255))
        for x in stride(from: 8, to: 52, by: 6) {
            for y in 5 ..< 15 {
                line[x, y] = PixelColor(red: 20, green: 20, blue: 30)
                line[x + 1, y] = PixelColor(red: 140, green: 140, blue: 145)
            }
        }
        let colors = try #require(TextInkEstimator.colors(in: line))
        #expect(colors.background == PixelColor(red: 255, green: 255, blue: 255))
        #expect(colors.ink.distance(to: PixelColor(red: 20, green: 20, blue: 30)) <= 4)

        var inverted = PixelImage(width: 40, height: 16, fill: PixelColor(red: 0, green: 90, blue: 200))
        for x in 10 ..< 30 {
            inverted[x, 8] = PixelColor(red: 255, green: 255, blue: 255)
        }
        let light = try #require(TextInkEstimator.colors(in: inverted))
        #expect(light.ink == PixelColor(red: 255, green: 255, blue: 255))
    }

    @Test func aMaskGridMapsOntoTheImagesPixels() throws {
        // 4×2 cells over an 8×4-pixel image: the right half of the top row is covered.
        let grid = MaskGrid(width: 4, height: 2, values: [0, 0, 1, 1, 0, 0, 0, 0])
        let box = try #require(grid.boundingBox(in: CGSize(width: 8, height: 4)))
        #expect(box == PixelRect(x: 4, y: 0, width: 4, height: 2))
        #expect(grid.coverage(x: 6, y: 0, in: CGSize(width: 8, height: 4)) == 1)
        #expect(grid.coverage(x: 0, y: 3, in: CGSize(width: 8, height: 4)) == 0)
        // Between a covered and an empty cell the edge is soft.
        let edge = grid.coverage(x: 4, y: 0, in: CGSize(width: 8, height: 4))
        #expect(edge > 0 && edge < 1)
        let grown = grid.dilated()
        #expect(grown.values == [0, 1, 1, 1, 0, 1, 1, 1])
        #expect(MaskGrid(width: 2, height: 2, values: [0, 0, 0, 0]).boundingBox(in: CGSize(width: 4, height: 4)) == nil)
    }

    @Test func instanceLabelsBecomeOneMaskEach() {
        let labels: [UInt8] = [0, 1, 1, 0, 2, 2, 0, 0, 2]
        let grids = ObjectDetector.grids(labels: labels, width: 3, height: 3, instances: [1, 2, 3])
        #expect(grids.count == 2)
        #expect(grids[0].grid.values == [0, 1, 1, 0, 0, 0, 0, 0, 0] && abs(grids[0].share - 2.0 / 9) < 0.0001)
        #expect(grids[1].grid.values == [0, 0, 0, 0, 1, 1, 0, 0, 1])
        let rect = ObjectDetector.pixelRect(
            fromNormalized: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            in: CGSize(width: 1000, height: 500)
        )
        for (value, expected) in [(rect.minX, 100.0), (rect.minY, 200), (rect.width, 300), (rect.height, 200)] {
            #expect(abs(value - expected) < 0.0001)
        }
    }

    @Test func linesGroupIntoBlocks() {
        let blocks = LineGrouping.blocks([
            CGRect(x: 0, y: 0, width: 100, height: 10),
            CGRect(x: 0, y: 13, width: 80, height: 10),
            CGRect(x: 2, y: 26, width: 90, height: 10),
            CGRect(x: 0, y: 60, width: 60, height: 10),
            CGRect(x: 300, y: 13, width: 50, height: 10),
            CGRect(x: 0, y: 73, width: 200, height: 30),
        ])
        #expect(blocks == [
            CGRect(x: 0, y: 0, width: 100, height: 36),
            CGRect(x: 300, y: 13, width: 50, height: 10),
            CGRect(x: 0, y: 60, width: 60, height: 10),
            CGRect(x: 0, y: 73, width: 200, height: 30),
        ])
    }

    @Test func barsAreAsLongAsTheLineAndAsTallAsItsLetters() {
        let bar = SimplifyGeometry.bar(for: CGRect(x: 10, y: 20, width: 100, height: 20))
        #expect(bar.minX == 10 && bar.width == 100)
        #expect(abs(bar.height - 8.4) < 0.0001)
        #expect(abs(bar.midY - 30.8) < 0.0001)
        let tiny = SimplifyGeometry.bar(for: CGRect(x: 0, y: 0, width: 1, height: 3))
        #expect(tiny.height == SimplifyGeometry.minimumHeight && tiny.width >= tiny.height)
        #expect(Bar(rect: bar, color: .black).cornerRadius == bar.height / 2)
    }
}
