import CoreGraphics
@testable import DiskAnalyzer
import Foundation
import Testing

/// The sunburst's angles: proportional to size, nested inside the parent's span, thin segments merged.
struct SunburstLayoutTests {
    private let tree = Fixtures.tree([
        "A/a1.mov": 500_000_000,
        "A/a2.mov": 250_000_000,
        "B/b.zip": 200_000_000,
        "c.dmg": 50_000_000,
    ])

    @Test func theFirstRingSharesTheCircleBySize() {
        let ring = SunburstLayout.segments(in: tree, root: ScanTree.rootIndex).filter { $0.depth == 1 }
        #expect(ring.map { tree.name(of: $0.node) } == ["A", "B", "c.dmg"])
        let spans = ring.map(\.span)
        #expect(abs(spans[0] - 0.75 * SunburstLayout.fullTurn) < 1e-9)
        #expect(abs(spans[1] - 0.2 * SunburstLayout.fullTurn) < 1e-9)
        #expect(abs(spans.reduce(0, +) - SunburstLayout.fullTurn) < 1e-9)
        #expect(ring[0].start == 0)
        #expect(abs(ring[1].start - ring[0].end) < 1e-12)
    }

    @Test func childrenFitInsideTheirParent() throws {
        let segments = SunburstLayout.segments(in: tree, root: ScanTree.rootIndex)
        let parent = try #require(segments.first { $0.depth == 1 && tree.name(of: $0.node) == "A" })
        let children = segments.filter { $0.depth == 2 && $0.branch == parent.branch }
        #expect(children.count == 2)
        for child in children {
            #expect(child.start >= parent.start - 1e-12)
            #expect(child.end <= parent.end + 1e-12)
        }
        #expect(abs(children.map(\.span).reduce(0, +) - parent.span) < 1e-9)
    }

    @Test func thinSegmentsAreMergedPerFolder() {
        var files: [String: Int64] = ["big.mov": 10_000_000_000]
        for number in 0 ..< 50 {
            files["small\(number).txt"] = 1_000_000
        }
        let tree = Fixtures.tree(files)
        let ring = SunburstLayout.segments(in: tree, root: ScanTree.rootIndex).filter { $0.depth == 1 }
        #expect(ring.count == 2)
        let merged = ring.first { $0.node == ScanNode.none }
        #expect(merged?.mergedCount == 50)
        #expect(merged?.parent == ScanTree.rootIndex)
        #expect(abs((merged?.span ?? 0) - SunburstLayout.fullTurn * 50 / 10050) < 1e-9)
    }

    @Test func ringsStopAtTheConfiguredDepth() {
        let tree = Fixtures.tree(["a/b/c/d/e/f/g/file.bin": 5_000_000])
        var options = SunburstLayout.Options()
        options.rings = 3
        let segments = SunburstLayout.segments(in: tree, root: ScanTree.rootIndex, options: options)
        #expect(segments.map(\.depth).max() == 3)
    }

    @Test func pointsMapToRingsAndAngles() throws {
        let rings = SunburstLayout.Rings(bounds: CGRect(x: 0, y: 0, width: 216, height: 216), rings: 5)
        #expect(rings.center == CGPoint(x: 108, y: 108))
        #expect(rings.locate(CGPoint(x: 108, y: 108), flipped: true)?.depth == 0)
        // Straight up from the center, in the first ring, is angle 0; to the right is a quarter turn.
        let up = try #require(rings.locate(CGPoint(x: 108, y: 108 - rings.inner(1) - 1), flipped: true))
        #expect(up.depth == 1)
        #expect(abs(up.angle) < 1e-9)
        let right = try #require(rings.locate(CGPoint(x: 108 + rings.inner(2) + 1, y: 108), flipped: true))
        #expect(right.depth == 2)
        #expect(abs(right.angle - .pi / 2) < 1e-9)
        #expect(rings.locate(CGPoint(x: 0, y: 0), flipped: true) == nil)
    }

    @Test func theSegmentUnderThePointIsFound() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)
        let segments = SunburstLayout.segments(in: tree, root: ScanTree.rootIndex)
        let rings = SunburstLayout.Rings(bounds: bounds, rings: 5)
        // Just right of twelve o'clock in the first ring is the largest folder, A.
        let point = CGPoint(x: 202, y: 200 - rings.inner(1) - 4)
        let hit = SunburstLayout.segment(at: point, in: segments, rings: rings, flipped: true)
        #expect(hit.map { tree.name(of: $0.node) } == "A")
        #expect(SunburstLayout.segment(at: CGPoint(x: 200, y: 200), in: segments, rings: rings, flipped: true) == nil)
    }
}
