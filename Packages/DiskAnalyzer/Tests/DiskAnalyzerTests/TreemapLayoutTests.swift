import CoreGraphics
@testable import DiskAnalyzer
import Testing

/// The squarified treemap: areas proportional to sizes, inside the bounds, without overlaps, close to square.
struct TreemapLayoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)

    @Test(arguments: [
        [6.0, 6, 4, 3, 2, 2, 1],
        [100.0],
        [50.0, 50],
        [90.0, 5, 3, 1, 0.5, 0.5],
        (1 ... 40).map { Double(41 - $0) },
    ])
    func areasAreProportionalAndFillTheBounds(_ values: [Double]) {
        let rects = TreemapLayout.squarify(values, in: bounds)
        #expect(rects.count == values.count)
        let total = values.reduce(0, +)
        let area = Double(bounds.width * bounds.height)
        for (value, rect) in zip(values, rects) {
            #expect(abs(Double(rect.width * rect.height) - value / total * area) < 0.5)
            #expect(bounds.insetBy(dx: -0.01, dy: -0.01).contains(rect))
        }
        let covered = rects.reduce(0.0) { $0 + Double($1.width * $1.height) }
        #expect(abs(covered - area) < 1)
    }

    @Test func rectanglesDoNotOverlap() {
        let rects = TreemapLayout.squarify([6, 6, 4, 3, 2, 2, 1], in: bounds)
        for (position, one) in rects.enumerated() {
            for other in rects[(position + 1)...] {
                let overlap = one.intersection(other)
                #expect(overlap.isNull || overlap.width * overlap.height < 0.01)
            }
        }
    }

    @Test func rectanglesStayCloseToSquare() {
        // The example of the paper: the worst aspect ratio squarified gives is under 3, where slicing gives 36.
        let rects = TreemapLayout.squarify([6, 6, 4, 3, 2, 2, 1], in: CGRect(x: 0, y: 0, width: 6, height: 4))
        let worst = rects.map { max($0.width / $0.height, $0.height / $0.width) }.max() ?? 0
        #expect(worst < 3)
    }

    @Test func zeroAndEmptyInputsGiveEmptyRectangles() {
        #expect(TreemapLayout.squarify([], in: bounds).isEmpty)
        #expect(TreemapLayout.squarify([0, 0], in: bounds).allSatisfy { $0.width == 0 && $0.height == 0 })
        #expect(TreemapLayout.squarify([3], in: .zero) == [CGRect.zero])
    }

    @Test func tilesNestFoldersAndMergeWhatIsTooSmall() {
        var files: [String: Int64] = ["Big/a.mov": 600_000_000, "Big/b.mov": 300_000_000, "file.zip": 90_000_000]
        for number in 0 ..< 200 {
            files["Many/tiny\(number).txt"] = 1000
        }
        let tree = Fixtures.tree(files)
        let tiles = TreemapLayout.tiles(in: tree, root: ScanTree.rootIndex, bounds: bounds)
        let top = tiles.filter { $0.depth == 1 }
        #expect(top.compactMap { $0.node == ScanNode.none ? nil : tree.name(of: $0.node) } == ["Big", "file.zip"])
        // "Many" would be a sliver under 50 points in area, so it is part of the merged tile.
        #expect(top.contains { $0.node == ScanNode.none && $0.mergedCount == 1 })
        let nested = tiles.filter { $0.depth == 2 }.map { tree.name(of: $0.node) }.sorted()
        #expect(nested == ["a.mov", "b.mov"])
        let big = tiles.first { $0.depth == 1 && $0.node != ScanNode.none && tree.name(of: $0.node) == "Big" }
        for child in tiles where child.depth == 2 {
            #expect(big?.rect.contains(child.rect) == true)
            #expect(child.branch == big?.branch)
        }
    }

    @Test func theDeepestTileIsHit() throws {
        let tree = Fixtures.tree(["Big/a.mov": 600_000_000, "Big/b.mov": 300_000_000, "file.zip": 100_000_000])
        let tiles = TreemapLayout.tiles(in: tree, root: ScanTree.rootIndex, bounds: bounds)
        let inner = try #require(tiles.first { $0.depth == 2 })
        let hit = TreemapLayout.tile(at: CGPoint(x: inner.rect.midX, y: inner.rect.midY), in: tiles)
        #expect(hit?.node == inner.node)
        #expect(TreemapLayout.tile(at: CGPoint(x: -5, y: -5), in: tiles) == nil)
    }
}
