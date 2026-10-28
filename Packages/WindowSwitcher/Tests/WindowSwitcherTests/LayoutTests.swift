import CoreGraphics
import Testing
@testable import WindowSwitcher

/// Auto-size (PLAN §10.3): table tests and the constraints for many counts and screens.
struct LayoutTests {
    /// The 80 % × 60 % panel limits of the dev Mac's three displays.
    static let laptop = LayoutCalculator.maximumPanelSize(forVisibleFrame: CGSize(width: 1512, height: 949))
    static let external = LayoutCalculator.maximumPanelSize(forVisibleFrame: CGSize(width: 2560, height: 1415))
    static let hd = LayoutCalculator.maximumPanelSize(forVisibleFrame: CGSize(width: 1920, height: 1055))

    private func thumbnails(_ count: Int, in size: CGSize, maximumTile: CGFloat = 220, search: Bool = false) -> SwitcherLayout {
        LayoutCalculator.layout(
            count: count, style: .thumbnails, metrics: .thumbnails(maximumTileWidth: maximumTile), maximumSize: size, showsSearchBar: search
        )
    }

    @Test func theMaximumPanelIsEightyBySixtyPercent() {
        #expect(Self.laptop == CGSize(width: 1209, height: 569))
    }

    @Test func nothingToShowGivesTheEmptyPanel() {
        let layout = thumbnails(0, in: Self.laptop)
        #expect(layout.rows == 0 && layout.panelSize == CGSize(width: 360, height: 120))
        #expect(thumbnails(0, in: Self.laptop, search: true).panelSize.height == 156)
    }

    @Test func oneWindowGetsTheLargestTileCentered() {
        let layout = thumbnails(1, in: Self.laptop)
        #expect(layout.columns == 1 && layout.rows == 1 && layout.tileSize.width == 220)
        // 220 + 2 × 16 is narrower than the empty panel, so the tile is centered in it.
        #expect(layout.panelSize.width == 360)
        #expect(layout.frame(ofItem: 0).midX == 180)
    }

    @Test func fourWindowsFitOneRowOnABigScreen() {
        let layout = thumbnails(4, in: Self.external)
        #expect(layout.rows == 1 && layout.columns == 4 && layout.tileSize.width == 220)
        let expectedWidth: CGFloat = 4 * 220 + 3 * 12 + 2 * 16
        #expect(layout.panelSize.width == expectedWidth)
    }

    @Test func moreRowsWinWhenTheyAllowLargerTiles() {
        // One row of six would need 186-point tiles; two rows of three fit the full 220.
        let layout = thumbnails(6, in: Self.laptop)
        #expect(layout.rows == 2 && layout.columns == 3 && layout.tileSize.width == 220)
    }

    @Test func tilesShrinkBeforeTheyScroll() {
        let layout = thumbnails(20, in: Self.laptop)
        #expect(!layout.isScrolling)
        #expect(layout.tileSize.width < 220 && layout.tileSize.width >= 120)
    }

    @Test func manyWindowsScrollAtTheMinimumSize() {
        let layout = thumbnails(200, in: Self.laptop)
        #expect(layout.isScrolling)
        #expect(layout.tileSize.width == 120)
        #expect(layout.columns * layout.rows >= 200)
        #expect(layout.contentSize.height > layout.viewportSize.height)
    }

    @Test func theSearchBarTakesHeight() {
        let plain = thumbnails(3, in: Self.laptop)
        let searching = thumbnails(3, in: Self.laptop, search: true)
        #expect(searching.panelSize.height == plain.panelSize.height + 36)
        #expect(searching.searchBarHeight == 36 && plain.searchBarHeight == 0)
    }

    @Test(arguments: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 200])
    func everyLayoutFitsAndNeverOverlaps(_ count: Int) {
        for size in [Self.laptop, Self.external, Self.hd] {
            for style in DisplayStyle.allCases {
                let metrics = LayoutMetrics.forStyle(style, thumbnailWidth: 220)
                let layout = LayoutCalculator.layout(count: count, style: style, metrics: metrics, maximumSize: size, showsSearchBar: false)
                #expect(layout.panelSize.width <= size.width, "\(style) \(count) too wide")
                #expect(layout.panelSize.height <= size.height, "\(style) \(count) too tall")
                #expect(layout.columns * layout.rows >= count)
                #expect((layout.rows - 1) * layout.columns < count, "an empty last row")
                if !layout.isScrolling {
                    #expect(layout.tileSize.width >= metrics.minimumTileWidth || style == .titles)
                    #expect(layout.tileSize.width <= metrics.maximumTileWidth)
                }
                let frames = (0 ..< count).map(layout.frame(ofItem:))
                for (index, frame) in frames.enumerated() {
                    #expect(frame.maxX <= layout.contentSize.width + 0.5)
                    #expect(frame.maxY <= layout.contentSize.height + 0.5)
                    if index > 0 {
                        #expect(!frame.intersects(frames[index - 1]))
                    }
                }
            }
        }
    }

    @Test func appIconsHaveAFixedTile() {
        let layout = LayoutCalculator.layout(
            count: 7,
            style: .appIcons,
            metrics: .appIcons,
            maximumSize: Self.laptop,
            showsSearchBar: false
        )
        #expect(layout.tileSize == CGSize(width: 104, height: 106))
        #expect(layout.rows == 1 && layout.columns == 7)
    }

    @Test func titlesAreOneColumnThatScrollsWhenLong() {
        let short = LayoutCalculator.layout(count: 5, style: .titles, metrics: .titles, maximumSize: Self.laptop, showsSearchBar: false)
        #expect(short.columns == 1 && short.rows == 5 && short.visibleRows == 5 && !short.isScrolling)
        #expect(short.tileSize == CGSize(width: 600, height: 30))
        let long = LayoutCalculator.layout(count: 100, style: .titles, metrics: .titles, maximumSize: Self.laptop, showsSearchBar: false)
        #expect(long.isScrolling && long.visibleRows < 100)
    }

    @Test func theThumbnailSettingCapsTheTile() {
        #expect(thumbnails(2, in: Self.external, maximumTile: 360).tileSize.width == 360)
        // Below the minimum it is clamped to the minimum.
        #expect(thumbnails(2, in: Self.external, maximumTile: 60).tileSize.width == 120)
    }
}
