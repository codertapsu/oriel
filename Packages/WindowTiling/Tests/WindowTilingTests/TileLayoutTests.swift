import CoreGraphics
import Testing
@testable import WindowTiling

/// The frame of every layout (PLAN §7.14) on the dev Mac's arrangements: exact rects on the built-in display, and on
/// every display the rules that matter — inside the visible frame, neighbours meeting exactly, the gap honoured.
struct TileLayoutTests {
    private static let window = CGRect(x: 100, y: 200, width: 800, height: 500)
    private static let plain = TilingOptions()

    private func frame(_ action: TilingAction, on display: DisplayGeometry = Displays.laptop, step: Int = 0, gap: CGFloat = 0) -> CGRect? {
        TileLayout.placement(for: action, window: Self.window, on: display, step: step, options: TilingOptions(gap: gap))?.frame
    }

    // MARK: Exact rects on the built-in display (visible (0, 33, 1512, 879))

    @Test(arguments: [
        (TilingAction.leftHalf, CGRect(x: 0, y: 33, width: 756, height: 879)),
        (.rightHalf, CGRect(x: 756, y: 33, width: 756, height: 879)),
        (.topHalf, CGRect(x: 0, y: 33, width: 1512, height: 440)),
        (.bottomHalf, CGRect(x: 0, y: 473, width: 1512, height: 439)),
        (.topLeft, CGRect(x: 0, y: 33, width: 756, height: 440)),
        (.topRight, CGRect(x: 756, y: 33, width: 756, height: 440)),
        (.bottomLeft, CGRect(x: 0, y: 473, width: 756, height: 439)),
        (.bottomRight, CGRect(x: 756, y: 473, width: 756, height: 439)),
        (.firstThird, CGRect(x: 0, y: 33, width: 504, height: 879)),
        (.centerThird, CGRect(x: 504, y: 33, width: 504, height: 879)),
        (.lastThird, CGRect(x: 1008, y: 33, width: 504, height: 879)),
        (.firstTwoThirds, CGRect(x: 0, y: 33, width: 1008, height: 879)),
        (.lastTwoThirds, CGRect(x: 504, y: 33, width: 1008, height: 879)),
        (.maximize, CGRect(x: 0, y: 33, width: 1512, height: 879)),
        // 90 % of 1512 × 879, centered.
        (.almostMaximize, CGRect(x: 76, y: 77, width: 1361, height: 791)),
        // The window's own x and width, the full height.
        (.maximizeHeight, CGRect(x: 100, y: 33, width: 800, height: 879)),
        // The window's size in the middle.
        (.center, CGRect(x: 356, y: 223, width: 800, height: 500)),
    ])
    func everyLayoutOnTheBuiltInDisplay(_ action: TilingAction, _ expected: CGRect) {
        #expect(frame(action) == expected)
    }

    @Test(arguments: [TilingAction.smaller, .larger, .nextDisplay, .previousDisplay, .restore])
    func actionsThatAreNotLayoutsHaveNoFixedFrame(_ action: TilingAction) {
        #expect(frame(action) == nil)
    }

    // MARK: Every arrangement

    @Test(arguments: Displays.all)
    func everyLayoutStaysInsideTheVisibleFrame(_ display: DisplayGeometry) {
        for action in TilingAction.allCases {
            guard let frame = frame(action, on: display, gap: 12) else { continue }
            #expect(display.visibleFrame.contains(frame), "\(action) leaves the visible frame of display \(display.id)")
            #expect(frame.width > 0 && frame.height > 0)
            #expect(frame.origin.x == frame.origin.x.rounded() && frame.width == frame.width.rounded(), "\(action) is not on whole points")
        }
    }

    @Test(arguments: Displays.all)
    func halvesAndThirdsMeetExactlyAndFillTheScreen(_ display: DisplayGeometry) throws {
        let visible = display.visibleFrame
        let left = try #require(frame(.leftHalf, on: display))
        let right = try #require(frame(.rightHalf, on: display))
        #expect(left.minX == visible.minX && right.maxX == visible.maxX)
        #expect(left.maxX == right.minX)
        let top = try #require(frame(.topHalf, on: display))
        let bottom = try #require(frame(.bottomHalf, on: display))
        #expect(top.minY == visible.minY && bottom.maxY == visible.maxY && top.maxY == bottom.minY)
        let thirds = try [TilingAction.firstThird, .centerThird, .lastThird].map { try #require(frame($0, on: display)) }
        if display.isPortrait {
            #expect(thirds[0].minY == visible.minY && thirds[0].maxY == thirds[1].minY)
            #expect(thirds[1].maxY == thirds[2].minY && thirds[2].maxY == visible.maxY)
        } else {
            #expect(thirds[0].minX == visible.minX && thirds[0].maxX == thirds[1].minX)
            #expect(thirds[1].maxX == thirds[2].minX && thirds[2].maxX == visible.maxX)
        }
    }

    @Test func anOddWidthIsSplitWithoutOverlapOrGap() throws {
        // 1365 points from x = 73: the halves are 683 and 682 points.
        let left = try #require(frame(.leftHalf, on: Displays.below))
        let right = try #require(frame(.rightHalf, on: Displays.below))
        #expect(left == CGRect(x: 73, y: 1007, width: 683, height: 743))
        #expect(right == CGRect(x: 756, y: 1007, width: 682, height: 743))
    }

    @Test func theDockOnEitherSideIsLeftClear() {
        #expect(frame(.leftHalf, on: Displays.laptopDockLeft) == CGRect(x: 64, y: 33, width: 724, height: 949))
        #expect(frame(.rightHalf, on: Displays.laptopDockLeft) == CGRect(x: 788, y: 33, width: 724, height: 949))
        #expect(frame(.rightHalf, on: Displays.laptopDockRight) == CGRect(x: 724, y: 33, width: 724, height: 949))
        #expect(frame(.maximize, on: Displays.laptopDockRight) == CGRect(x: 0, y: 33, width: 1448, height: 949))
    }

    @Test func displaysLeftAboveAndRightOfTheMainOneUseTheirOwnCoordinates() {
        // Left: negative x, and its top above the primary's (negative y).
        #expect(frame(.leftHalf, on: Displays.left) == CGRect(x: -1920, y: -73, width: 960, height: 1055))
        #expect(frame(.bottomRight, on: Displays.left) == CGRect(x: -960, y: 455, width: 960, height: 527))
        // Above: entirely at negative y. The middle, -707.5, rounds away from zero, so the top half is 707 points tall.
        #expect(frame(.topHalf, on: Displays.above) == CGRect(x: -524, y: -1415, width: 2560, height: 707))
        #expect(frame(.bottomHalf, on: Displays.above) == CGRect(x: -524, y: -708, width: 2560, height: 708))
        #expect(frame(.maximize, on: Displays.above) == CGRect(x: -524, y: -1415, width: 2560, height: 1415))
        // Right, taller than the primary.
        #expect(frame(.lastThird, on: Displays.right) == CGRect(x: 3219, y: 25, width: 853, height: 1415))
    }

    @Test func thirdsStackOnAPortraitDisplay() {
        #expect(frame(.firstThird, on: Displays.portrait) == CGRect(x: 1512, y: 25, width: 1080, height: 632))
        #expect(frame(.centerThird, on: Displays.portrait) == CGRect(x: 1512, y: 657, width: 1080, height: 631))
        #expect(frame(.lastTwoThirds, on: Displays.portrait) == CGRect(x: 1512, y: 657, width: 1080, height: 1263))
        // Halves stay halves.
        #expect(frame(.leftHalf, on: Displays.portrait) == CGRect(x: 1512, y: 25, width: 540, height: 1895))
    }

    // MARK: Gaps

    @Test func aGapSeparatesNeighboursAndTheScreensEdges() throws {
        let left = try #require(frame(.leftHalf, gap: 10))
        let right = try #require(frame(.rightHalf, gap: 10))
        #expect(left == CGRect(x: 10, y: 43, width: 741, height: 859))
        #expect(right == CGRect(x: 761, y: 43, width: 741, height: 859))
        #expect(right.minX - left.maxX == 10)
        let topLeft = try #require(frame(.topLeft, gap: 10))
        let bottomLeft = try #require(frame(.bottomLeft, gap: 10))
        #expect(bottomLeft.minY - topLeft.maxY == 10)
        #expect(topLeft.minY == 43 && bottomLeft.maxY == 902)
        let thirds = try [TilingAction.firstThird, .centerThird, .lastThird].map { try #require(frame($0, gap: 10)) }
        #expect(thirds[1].minX - thirds[0].maxX == 10 && thirds[2].minX - thirds[1].maxX == 10)
        #expect(thirds[0].minX == 10 && thirds[2].maxX == 1502)
        #expect(frame(.maximize, gap: 10) == CGRect(x: 10, y: 43, width: 1492, height: 859))
    }

    @Test func aTwoThirdsAndAThirdKeepTheGapBetweenThem() throws {
        let wide = try #require(frame(.firstTwoThirds, gap: 8))
        let narrow = try #require(frame(.lastThird, gap: 8))
        #expect(narrow.minX - wide.maxX == 8)
    }

    @Test func almostMaximizeIgnoresTheGap() {
        #expect(frame(.almostMaximize, gap: 20) == frame(.almostMaximize))
    }

    @Test func aGapTooLargeForTheDisplayIsCapped() {
        let tiny = DisplayGeometry(
            id: 9,
            frame: CGRect(x: 0, y: 0, width: 120, height: 80),
            visibleFrame: CGRect(x: 0, y: 0, width: 120, height: 80)
        )
        #expect(tiny.effectiveGap(32) == 20)
        #expect(tiny.effectiveGap(-4) == 0)
        let maximized = TileLayout.placement(for: .maximize, window: Self.window, on: tiny, options: TilingOptions(gap: 32))?.frame
        #expect(maximized == CGRect(x: 20, y: 20, width: 80, height: 40))
    }

    // MARK: Sizes and anchors

    @Test func halvesTakeTheCycleSizes() {
        #expect(frame(.leftHalf, step: 1)?.width == 1008)
        #expect(frame(.leftHalf, step: 2)?.width == 504)
        #expect(frame(.leftHalf, step: 3)?.width == 756)
        #expect(frame(.rightHalf, step: 1) == CGRect(x: 504, y: 33, width: 1008, height: 879))
        #expect(frame(.bottomHalf, step: 2) == CGRect(x: 0, y: 619, width: 1512, height: 293))
    }

    @Test(arguments: [
        (TilingAction.leftHalf, TilePlacement.Anchor.start, TilePlacement.Anchor.center),
        (.rightHalf, .end, .center),
        (.topHalf, .center, .start),
        (.bottomHalf, .center, .end),
        (.topLeft, .start, .start),
        (.bottomRight, .end, .end),
        (.centerThird, .center, .center),
        (.lastTwoThirds, .end, .center),
        (.maximize, .center, .center),
        (.maximizeHeight, .start, .center),
        (.center, .center, .center),
    ])
    func layoutsKeepTheEdgesTheyShareWithTheScreen(
        _ action: TilingAction,
        _ horizontal: TilePlacement.Anchor,
        _ vertical: TilePlacement.Anchor
    ) {
        let placement = TileLayout.placement(for: action, window: Self.window, on: Displays.laptop, options: Self.plain)
        #expect(placement?.horizontal == horizontal)
        #expect(placement?.vertical == vertical)
    }

    @Test func maximizeHeightAndCenterKeepAWindowLargerThanTheScreenOnIt() {
        let huge = CGRect(x: -300, y: 0, width: 2000, height: 1200)
        let height = TileLayout.placement(for: .maximizeHeight, window: huge, on: Displays.laptop, options: Self.plain)?.frame
        #expect(height == CGRect(x: 0, y: 33, width: 1512, height: 879))
        let centered = TileLayout.placement(for: .center, window: huge, on: Displays.laptop, options: Self.plain)?.frame
        #expect(centered == CGRect(x: 0, y: 33, width: 1512, height: 879))
        // A window hanging off the right edge is moved in, keeping its width.
        let hanging = CGRect(x: 1200, y: 100, width: 600, height: 400)
        #expect(TileLayout.placement(for: .maximizeHeight, window: hanging, on: Displays.laptop, options: Self.plain)?.frame.minX == 912)
    }

    @Test func almostMaximizeFollowsItsSetting() {
        let options = TilingOptions(almostMaximizeFraction: 0.8)
        let frame = TileLayout.placement(for: .almostMaximize, window: Self.window, on: Displays.right, options: options)?.frame
        #expect(frame == CGRect(x: 1768, y: 167, width: 2048, height: 1132))
    }
}
