import CoreGraphics
import Testing
@testable import WindowTiling

/// Windows that cannot take a layout's size: they keep the layout's edges and stay on their screen (min-size clamping).
struct TileFittingTests {
    private func placement(_ action: TilingAction, on display: DisplayGeometry = Displays.laptop) throws -> TilePlacement {
        try #require(TileLayout.placement(
            for: action, window: CGRect(x: 100, y: 100, width: 800, height: 600), on: display, options: TilingOptions()
        ))
    }

    private func fitted(_ action: TilingAction, _ size: CGSize, on display: DisplayGeometry = Displays.laptop) throws -> CGRect {
        try TileFitting.fitted(placement(action, on: display), size: size, on: display)
    }

    @Test func aMinimumWidthKeepsTheRightHalfAgainstTheRightEdge() throws {
        // The right half is 756 points; this window cannot get narrower than 900.
        #expect(try fitted(.rightHalf, CGSize(width: 900, height: 879)) == CGRect(x: 612, y: 33, width: 900, height: 879))
        #expect(try fitted(.leftHalf, CGSize(width: 900, height: 879)) == CGRect(x: 0, y: 33, width: 900, height: 879))
    }

    @Test func aMinimumSizeKeepsAQuarterInItsCorner() throws {
        #expect(try fitted(.bottomRight, CGSize(width: 1000, height: 500)) == CGRect(x: 512, y: 412, width: 1000, height: 500))
        #expect(try fitted(.topLeft, CGSize(width: 1000, height: 500)) == CGRect(x: 0, y: 33, width: 1000, height: 500))
    }

    @Test func aMinimumWidthKeepsTheCenterThirdCentered() throws {
        // The center third runs from 504 to 1008; a 700-point window sits around its middle, 756.
        #expect(try fitted(.centerThird, CGSize(width: 700, height: 879)) == CGRect(x: 406, y: 33, width: 700, height: 879))
    }

    @Test func aMaximumSizeIsCenteredInMaximize() throws {
        // System Settings-like: a fixed width, a limited height.
        #expect(try fitted(.maximize, CGSize(width: 715, height: 600)) == CGRect(x: 399, y: 173, width: 715, height: 600))
    }

    @Test func snappingToCharactersKeepsTheBottomHalfOnTheBottomEdge() throws {
        // A terminal rounds the bottom half's 439 points down to 432.
        #expect(try fitted(.bottomHalf, CGSize(width: 1512, height: 432)) == CGRect(x: 0, y: 480, width: 1512, height: 432))
    }

    @Test func aWindowLargerThanTheScreenKeepsItsTitleBarOnIt() throws {
        #expect(try fitted(.rightHalf, CGSize(width: 1600, height: 1000)) == CGRect(x: 0, y: 33, width: 1600, height: 1000))
        // On a display left of and above the main one.
        let left = try fitted(.lastThird, CGSize(width: 2000, height: 1100), on: Displays.left)
        #expect(left.origin == CGPoint(x: -1920, y: -73))
    }

    @Test(arguments: Displays.all)
    func everyFittedWindowThatFitsStaysOnItsDisplay(_ display: DisplayGeometry) {
        let visible = display.visibleFrame
        let size = CGSize(width: min(900, visible.width), height: min(700, visible.height))
        for action in TilingAction.allCases {
            guard let placement = TileLayout.placement(
                for: action, window: CGRect(x: 0, y: 0, width: 300, height: 200), on: display, options: TilingOptions(gap: 8)
            ) else { continue }
            let frame = TileFitting.fitted(placement, size: size, on: display)
            #expect(visible.contains(frame), "\(action) puts a \(size) window off display \(display.id)")
        }
    }

    // MARK: Reachable restore frames

    @Test func aRestoreFrameWhoseTitleBarShowsIsKept() {
        let partlyOff = CGRect(x: 1300, y: 600, width: 800, height: 600)
        #expect(TileFitting.reachable(partlyOff, displays: [Displays.laptop], fallback: Displays.laptop) == partlyOff)
        let onTheRight = CGRect(x: 3000, y: 100, width: 800, height: 600)
        #expect(TileFitting.reachable(onTheRight, displays: Displays.row, fallback: Displays.laptop) == onTheRight)
    }

    @Test func aRestoreFrameUnderTheMenuBarOrOffEveryScreenIsBroughtBack() {
        // Its title bar would be hidden above the top of the only display.
        let above = CGRect(x: 100, y: -500, width: 800, height: 600)
        #expect(TileFitting.reachable(above, displays: [Displays.laptop], fallback: Displays.laptop) == CGRect(
            x: 356,
            y: 173,
            width: 800,
            height: 600
        ))
        let farAway = CGRect(x: 9000, y: 9000, width: 400, height: 300)
        #expect(TileFitting.reachable(farAway, displays: Displays.row, fallback: Displays.left) == CGRect(
            x: -1160,
            y: 305,
            width: 400,
            height: 300
        ))
    }
}
