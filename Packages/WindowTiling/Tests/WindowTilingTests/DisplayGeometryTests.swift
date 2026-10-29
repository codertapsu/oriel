import CoreGraphics
import Testing
@testable import WindowTiling

/// `NSScreen` frames in Accessibility's coordinates for every arrangement, which display a window is on, and the
/// order Next and Previous Display go in.
struct DisplayGeometryTests {
    @Test(arguments: [
        (Displays.laptop, CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 0, y: 33, width: 1512, height: 879)),
        (Displays.laptopDockLeft, CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 64, y: 33, width: 1448, height: 949)),
        (Displays.laptopDockRight, CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 0, y: 33, width: 1448, height: 949)),
        (Displays.right, CGRect(x: 1512, y: 0, width: 2560, height: 1440), CGRect(x: 1512, y: 25, width: 2560, height: 1415)),
        (Displays.left, CGRect(x: -1920, y: -98, width: 1920, height: 1080), CGRect(x: -1920, y: -73, width: 1920, height: 1055)),
        (Displays.above, CGRect(x: -524, y: -1440, width: 2560, height: 1440), CGRect(x: -524, y: -1415, width: 2560, height: 1415)),
        (Displays.below, CGRect(x: 73, y: 982, width: 1365, height: 768), CGRect(x: 73, y: 1007, width: 1365, height: 743)),
        (Displays.portrait, CGRect(x: 1512, y: 0, width: 1080, height: 1920), CGRect(x: 1512, y: 25, width: 1080, height: 1895)),
    ])
    func cocoaFramesFlipIntoAccessibilityCoordinates(_ display: DisplayGeometry, _ frame: CGRect, _ visible: CGRect) {
        #expect(display.frame == frame)
        #expect(display.visibleFrame == visible)
    }

    @Test func onlyATallerThanWideDisplayIsPortrait() {
        #expect(Displays.portrait.isPortrait)
        #expect(!Displays.laptop.isPortrait && !Displays.above.isPortrait)
    }

    @Test func aWindowBelongsToTheDisplayShowingMostOfIt() {
        let displays = Displays.row
        // Mostly on the right display, a little on the laptop.
        #expect(DisplayArrangement.index(of: CGRect(x: 1400, y: 100, width: 800, height: 600), in: displays) == 2)
        #expect(DisplayArrangement.index(of: CGRect(x: -100, y: 100, width: 800, height: 600), in: displays) == 0)
        #expect(DisplayArrangement.index(of: CGRect(x: -1000, y: -50, width: 800, height: 600), in: displays) == 1)
        // Off every display: the nearest visible frame.
        #expect(DisplayArrangement.index(of: CGRect(x: 5000, y: 300, width: 400, height: 300), in: displays) == 2)
        #expect(DisplayArrangement.index(of: CGRect(x: 300, y: 1600, width: 400, height: 300), in: displays) == 0)
        #expect(DisplayArrangement.index(of: .zero, in: []) == nil)
    }

    @Test func nextAndPreviousDisplayGoLeftToRightAndWrap() {
        // In the array: laptop, left, right; on the desk: left, laptop, right.
        let displays = Displays.row
        #expect(DisplayArrangement.neighbour(of: 0, forward: true, in: displays) == 2)
        #expect(DisplayArrangement.neighbour(of: 2, forward: true, in: displays) == 1)
        #expect(DisplayArrangement.neighbour(of: 1, forward: true, in: displays) == 0)
        #expect(DisplayArrangement.neighbour(of: 0, forward: false, in: displays) == 1)
        #expect(DisplayArrangement.neighbour(of: 1, forward: false, in: displays) == 2)
    }

    @Test func stackedDisplaysGoTopToBottom() {
        // Above starts further left than the laptop, so it comes first; below starts right of the laptop.
        let displays = [Displays.laptop, Displays.below, Displays.above]
        #expect(DisplayArrangement.neighbour(of: 2, forward: true, in: displays) == 0)
        #expect(DisplayArrangement.neighbour(of: 0, forward: true, in: displays) == 1)
        #expect(DisplayArrangement.neighbour(of: 1, forward: true, in: displays) == 2)
        // Two displays with the same left edge: the upper one first.
        let upper = DisplayGeometry(
            id: 7,
            frame: CGRect(x: 0, y: -900, width: 1600, height: 900),
            visibleFrame: CGRect(x: 0, y: -875, width: 1600, height: 875)
        )
        #expect(DisplayArrangement.neighbour(of: 1, forward: true, in: [Displays.laptop, upper]) == 0)
    }

    @Test func oneDisplayHasNoNeighbour() {
        #expect(DisplayArrangement.neighbour(of: 0, forward: true, in: [Displays.laptop]) == 0)
        #expect(DisplayArrangement.neighbour(of: 3, forward: true, in: Displays.row) == 3)
    }

    @Test func optionsStayInTheRangesSettingsOffers() {
        let options = TilingOptions(gap: 80, almostMaximizeFraction: 2)
        #expect(options.gap == 32 && options.almostMaximizeFraction == 0.95)
        let low = TilingOptions(gap: -5, almostMaximizeFraction: 0.1)
        #expect(low.gap == 0 && low.almostMaximizeFraction == 0.6)
        #expect(TilingOptions.fraction(forStep: 0) == 0.5)
        #expect(abs(TilingOptions.fraction(forStep: 4) - 2.0 / 3) < 1e-9)
        #expect(abs(TilingOptions.fraction(forStep: -1) - 1.0 / 3) < 1e-9)
    }
}
