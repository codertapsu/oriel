import CoreGraphics
import Testing
@testable import WindowSwitcher

/// Auto-size with group headers and key hints (PLAN §10.3, §7.1.11): the band above every grid row, the header above every
/// list group, the hints under the tiles, and ungrouped layouts exactly as before.
struct GroupedLayoutTests {
    private static let laptop = LayoutTests.laptop

    private func grid(_ count: Int, groupStarts: [Int]? = nil, hints: Bool = false, in size: CGSize = Self.laptop) -> SwitcherLayout {
        LayoutCalculator.layout(
            count: count, style: .thumbnails, metrics: .thumbnails(maximumTileWidth: 220), maximumSize: size, showsSearchBar: false,
            groupStarts: groupStarts, showsHints: hints
        )
    }

    private func list(_ count: Int, groupStarts: [Int]? = nil, hints: Bool = false) -> SwitcherLayout {
        LayoutCalculator.layout(
            count: count, style: .titles, metrics: .titles, maximumSize: Self.laptop, showsSearchBar: false,
            groupStarts: groupStarts, showsHints: hints
        )
    }

    @Test func ungroupedLayoutsAreUnchanged() {
        for count in [1, 6, 20, 200] {
            let plain = LayoutCalculator.layout(
                count: count, style: .thumbnails, metrics: .thumbnails(maximumTileWidth: 220), maximumSize: Self.laptop,
                showsSearchBar: false
            )
            #expect(grid(count) == plain)
            #expect(plain.headers == .none && plain.footerHeight == 0)
        }
    }

    @Test func aGroupedGridCarriesABandAboveEveryRow() {
        let layout = grid(6, groupStarts: [0, 2, 5])
        #expect(layout.headers == .aboveRows(height: 22))
        // The padding, then the band. (Typed: #expect sees literal-only sums as Int.)
        let firstTop: CGFloat = 16 + 22
        #expect(layout.frame(ofItem: 0).minY == firstTop)
        let second = layout.frame(ofItem: layout.columns)
        #expect(second.minY == 16 + 22 + layout.tileSize.height + 12 + 22)
        #expect(layout.panelSize.height <= Self.laptop.height)
        #expect(layout.contentSize.height == layout.frame(ofItem: 5).maxY + 16)
    }

    @Test func eachGroupIsLabelledOverItsTilesInEveryRowItReaches() throws {
        // Three columns: Safari 0–1, Notes 2–4 (it runs into the second row), Mail 5.
        let layout = grid(6, groupStarts: [0, 2, 5], in: CGSize(width: 800, height: 700))
        try #require(layout.columns == 3)
        let placements = layout.headerPlacements(for: [0 ..< 2, 2 ..< 5, 5 ..< 6])
        #expect(placements.map(\.group) == [0, 1, 1, 2])
        let first = layout.frame(ofItem: 0)
        let second = layout.frame(ofItem: 1)
        #expect(placements[0].frame == CGRect(x: first.minX, y: first.minY - 22, width: second.maxX - first.minX, height: 22))
        // Notes' second label starts the second row and stops at its last tile.
        let wrapped = placements[2].frame
        #expect(wrapped.minX == layout.frame(ofItem: 3).minX && wrapped.maxX == layout.frame(ofItem: 4).maxX)
        #expect(wrapped.maxY == layout.frame(ofItem: 3).minY)
        #expect(placements[3].frame.minX == layout.frame(ofItem: 5).minX)
    }

    @Test func aGroupedListHasAHeaderAboveEachGroup() {
        let layout = list(5, groupStarts: [0, 2, 4])
        #expect(layout.headers == .aboveGroups(starts: [0, 2, 4], height: 26))
        // Rows are 30 points with 2 between them; every group adds its 26-point header.
        let rowTops: [CGFloat] = [8 + 26, 8 + 26 + 32, 8 + 2 * 26 + 2 * 32, 8 + 2 * 26 + 3 * 32, 8 + 3 * 26 + 4 * 32]
        #expect((0 ..< 5).map { layout.frame(ofItem: $0).minY } == rowTops)
        let placements = layout.headerPlacements(for: [0 ..< 2, 2 ..< 4, 4 ..< 5])
        let tops: [CGFloat] = [8, 98, 188]
        #expect(placements.map(\.frame.minY) == tops)
        #expect(placements.allSatisfy { $0.frame.height == 26 && $0.frame.width == layout.tileSize.width })
        // 2 × 8 padding, 5 rows of 30, 4 gaps of 2 and 3 headers of 26.
        let expectedHeight: CGFloat = 252
        #expect(layout.height(ofRows: 5) == expectedHeight)
        #expect(!layout.isScrolling)
    }

    @Test func aLongGroupedListScrollsWithEveryVisibleRowAndHeaderInside() {
        let starts = Array(stride(from: 0, to: 60, by: 3))
        let layout = list(60, groupStarts: starts)
        #expect(layout.isScrolling)
        #expect(layout.height(ofRows: layout.visibleRows) <= Self.laptop.height)
        #expect(layout.height(ofRows: layout.visibleRows + 1) > Self.laptop.height)
        #expect(layout.panelSize.height <= Self.laptop.height)
    }

    @Test func theHintsTakeTheirLineUnderTheTiles() {
        let plain = grid(4)
        let hinted = grid(4, hints: true)
        #expect(hinted.footerHeight == 26)
        #expect(hinted.panelSize.height == plain.panelSize.height + 26)
        #expect(hinted.viewportSize.height == plain.viewportSize.height)
        // A full panel gives the hints room by shrinking the tiles, not by growing past its limit.
        let many = grid(40, hints: true)
        #expect(many.panelSize.height <= Self.laptop.height)
        // Nothing to act on, nothing to hint.
        #expect(grid(0, hints: true).footerHeight == 0)
        let listed = list(3, hints: true)
        #expect(listed.panelSize.height == list(3).panelSize.height + 26)
    }

    @Test func appIconsNeverShowGroupHeaders() {
        let layout = LayoutCalculator.layout(
            count: 5, style: .appIcons, metrics: .appIcons, maximumSize: Self.laptop, showsSearchBar: false, groupStarts: [0, 2]
        )
        #expect(layout.headers == .none)
        #expect(layout.headerPlacements(for: [0 ..< 2, 2 ..< 5]).isEmpty)
    }

    @Test func revealingAnItemIncludesItsLabel() {
        let layout = grid(6, groupStarts: [0, 3])
        let reveal = layout.revealRect(ofItem: 0)
        #expect(reveal.minY == layout.frame(ofItem: 0).minY - 22 - 16)
        let plain = grid(6).revealRect(ofItem: 0)
        #expect(plain == grid(6).frame(ofItem: 0).insetBy(dx: 0, dy: -16))
    }
}
