import CoreGraphics
import Testing
@testable import WindowTiling

/// The whole Accessibility sequence against simulated windows: size, position, size again when it did not take, the
/// read-back fit, the history, the windows that are skipped, and `AXEnhancedUserInterface`.
struct WindowArrangerTests {
    private static let original = CGRect(x: 300, y: 200, width: 700, height: 500)
    private static let options = TilingOptions()

    private func arranger(_ window: SimulatedWindow) -> (WindowArranger<FakeWindowAccess>, FakeWindowAccess) {
        let access = FakeWindowAccess(window)
        return (WindowArranger(access: access), access)
    }

    @Test func aPlainWindowIsSizedThenMoved() {
        let window = SimulatedWindow(frame: Self.original)
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.leftHalf, pid: 42, displays: [Displays.laptop], options: Self.options) == .moved)
        #expect(window.frame == CGRect(x: 0, y: 33, width: 756, height: 879))
        #expect(window.calls == [.size(CGSize(width: 756, height: 879)), .position(CGPoint(x: 0, y: 33))])
        #expect(arranger.history.count == 1)
    }

    @Test func aMinimumWidthIsReadBackAndTheWindowStaysOnScreen() {
        let window = SimulatedWindow(frame: Self.original)
        window.minimumSize = CGSize(width: 900, height: 300)
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.rightHalf, pid: 42, displays: [Displays.laptop], options: Self.options) == .moved)
        // Asked for 756 at x = 756; took 900, so it moves left to keep the right edge on the screen's.
        #expect(window.frame == CGRect(x: 612, y: 33, width: 900, height: 879))
        #expect(window.calls.last == .position(CGPoint(x: 612, y: 33)))
        #expect(Displays.laptop.visibleFrame.contains(window.frame))
    }

    @Test func aFixedSizeWindowIsOnlyMovedToWhereItsSizeLinesUp() {
        let window = SimulatedWindow(frame: Self.original)
        window.canResize = false
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.bottomRight, pid: 42, displays: [Displays.laptop], options: Self.options) == .moved)
        #expect(window.calls == [.position(CGPoint(x: 812, y: 412))])
        #expect(window.frame == CGRect(x: 812, y: 412, width: 700, height: 500))
    }

    @Test func aWindowKeptWithinItsDisplayGetsItsSizeAgainOnTheTallerOne() {
        // Like apps that cap a window at its screen: it cannot be 1415 tall until it is on the 1415-point display.
        let window = SimulatedWindow(frame: Self.original)
        window.keepsWithinDisplays = Displays.row
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.maximize, pid: 42, displays: Displays.row, options: Self.options) == .moved)
        #expect(arranger.arrange(.nextDisplay, pid: 42, displays: Displays.row, options: Self.options) == .moved)
        #expect(window.frame == CGRect(x: 1512, y: 25, width: 2560, height: 1415))
        // Size (capped at the laptop's 879), position, then the size again on the tall display.
        #expect(window.calls.suffix(3) == [
            .size(CGSize(width: 2560, height: 1415)),
            .position(CGPoint(x: 1512, y: 25)),
            .size(CGSize(width: 2560, height: 1415)),
        ])
    }

    @Test func snappingToCharactersIsLinedUpWithTheLayout() {
        let window = SimulatedWindow(frame: Self.original)
        window.cell = CGSize(width: 7, height: 16)
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.bottomRight, pid: 42, displays: [Displays.laptop], options: Self.options) == .moved)
        // 756 × 439 snaps to 756 × 432; the window keeps the bottom-right corner.
        #expect(window.frame == CGRect(x: 756, y: 480, width: 756, height: 432))
        // And a second press finds it where it was left: the history knows it.
        #expect(arranger.history.record(for: ObjectIdentifier(window), at: window.frame) != nil)
    }

    @Test func threePressesCycleThroughTheSizesAndRestoreUndoesTheRun() {
        let window = SimulatedWindow(frame: Self.original)
        var (arranger, _) = arranger(window)
        let displays = [Displays.laptop]
        var widths: [CGFloat] = []
        for _ in 0 ..< 3 {
            #expect(arranger.arrange(.leftHalf, pid: 42, displays: displays, options: Self.options) == .moved)
            widths.append(window.frame.width)
        }
        #expect(widths == [756, 1008, 504])
        #expect(arranger.arrange(.maximize, pid: 42, displays: displays, options: Self.options) == .moved)
        #expect(arranger.arrange(.restore, pid: 42, displays: displays, options: Self.options) == .moved)
        #expect(window.frame == Self.original)
        // Restored and forgotten: a second Restore has nothing to do.
        #expect(arranger.arrange(.restore, pid: 42, displays: displays, options: Self.options) == .unchanged)
    }

    @Test func movingTheWindowByHandRestartsTheCycleAndRestoresToTheNewFrame() {
        let window = SimulatedWindow(frame: Self.original)
        var (arranger, _) = arranger(window)
        let displays = [Displays.laptop]
        _ = arranger.arrange(.leftHalf, pid: 42, displays: displays, options: Self.options)
        let dragged = CGRect(x: 400, y: 300, width: 600, height: 400)
        window.frame = dragged
        _ = arranger.arrange(.leftHalf, pid: 42, displays: displays, options: Self.options)
        #expect(window.frame.width == 756)
        _ = arranger.arrange(.restore, pid: 42, displays: displays, options: Self.options)
        #expect(window.frame == dragged)
    }

    @Test func nextDisplayMovesTheWindowAcross() {
        let window = SimulatedWindow(frame: Self.original)
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.nextDisplay, pid: 42, displays: Displays.row, options: Self.options) == .moved)
        #expect(DisplayArrangement.index(of: window.frame, in: Displays.row) == 2)
        #expect(window.frame.size == Self.original.size)
        #expect(arranger.arrange(.restore, pid: 42, displays: Displays.row, options: Self.options) == .moved)
        #expect(window.frame == Self.original)
    }

    @Test func fullScreenWindowsAndSheetsAreLeftAlone() {
        let fullScreen = SimulatedWindow(pid: 1, frame: Self.original)
        fullScreen.isFullScreen = true
        let sheet = SimulatedWindow(pid: 2, frame: Self.original)
        sheet.role = WindowSnapshot.sheetRole
        let fixed = SimulatedWindow(pid: 3, frame: Self.original)
        fixed.canMove = false
        let minimized = SimulatedWindow(pid: 4, frame: Self.original)
        minimized.isMinimized = true
        let other = SimulatedWindow(pid: 5, frame: Self.original)
        other.role = "AXPopover"
        var arranger = WindowArranger(access: FakeWindowAccess(fullScreen, sheet, fixed, minimized, other))
        let displays = [Displays.laptop]
        #expect(arranger.arrange(.leftHalf, pid: 1, displays: displays, options: Self.options) == .skipped(.fullScreen))
        #expect(arranger.arrange(.leftHalf, pid: 2, displays: displays, options: Self.options) == .skipped(.sheet))
        #expect(arranger.arrange(.leftHalf, pid: 3, displays: displays, options: Self.options) == .skipped(.notMovable))
        #expect(arranger.arrange(.leftHalf, pid: 4, displays: displays, options: Self.options) == .noWindow)
        #expect(arranger.arrange(.leftHalf, pid: 5, displays: displays, options: Self.options) == .skipped(.notMovable))
        for window in [fullScreen, sheet, fixed, minimized, other] {
            #expect(window.calls.isEmpty && window.frame == Self.original)
        }
        #expect(arranger.history.count == 0)
    }

    @Test func appsWithoutAWindowOrThatDoNotAnswer() {
        let window = SimulatedWindow(pid: 7, frame: Self.original)
        let access = FakeWindowAccess(window)
        var arranger = WindowArranger(access: access)
        let displays = [Displays.laptop]
        #expect(arranger.arrange(.leftHalf, pid: 99, displays: displays, options: Self.options) == .noWindow)
        access.refusing = [7]
        #expect(arranger.arrange(.leftHalf, pid: 7, displays: displays, options: Self.options) == .appDidNotRespond)
        access.refusing = []
        access.silent = [7]
        #expect(arranger.arrange(.leftHalf, pid: 7, displays: displays, options: Self.options) == .appDidNotRespond)
        access.silent = []
        #expect(arranger.arrange(.leftHalf, pid: 7, displays: [], options: Self.options) == .unchanged)
        #expect(window.calls.isEmpty)
    }

    @Test func aWindowThatRefusesToMoveIsReported() {
        // Settable according to its attributes, yet every size and position change fails.
        let window = SimulatedWindow(frame: Self.original)
        var arranger = WindowArranger(access: StubbornAccess(window: window))
        #expect(arranger.arrange(.leftHalf, pid: 42, displays: [Displays.laptop], options: Self.options) == .skipped(.notMovable))
        #expect(arranger.history.count == 0)
        #expect(window.frame == Self.original)
    }

    @Test func enhancedUserInterfaceIsOffWhileTheWindowMovesAndOnAgainAfter() {
        let window = SimulatedWindow(frame: Self.original)
        let access = FakeWindowAccess(window)
        access.enhancedUserInterface[42] = true
        var arranger = WindowArranger(access: access)
        #expect(arranger.arrange(.maximize, pid: 42, displays: [Displays.laptop], options: Self.options) == .moved)
        #expect(!access.enhancedStatesDuringMoves.isEmpty)
        #expect(access.enhancedStatesDuringMoves.allSatisfy { !$0 })
        #expect(access.enhancedUserInterface[42] == true)
    }

    @Test func nothingToDoTouchesNothing() {
        let window = SimulatedWindow(frame: CGRect(x: 0, y: 33, width: 1512, height: 879))
        var (arranger, _) = arranger(window)
        #expect(arranger.arrange(.larger, pid: 42, displays: [Displays.laptop], options: Self.options) == .unchanged)
        #expect(arranger.arrange(.nextDisplay, pid: 42, displays: [Displays.laptop], options: Self.options) == .unchanged)
        #expect(window.calls.isEmpty)
    }
}

/// Answers like an app whose windows Accessibility can read but not move.
private final class StubbornAccess: WindowAccessing {
    let window: SimulatedWindow

    init(window: SimulatedWindow) {
        self.window = window
    }

    func focusedWindow(of _: Int32) -> WindowLookup<SimulatedWindow> {
        .found(window)
    }

    func key(of window: SimulatedWindow) -> ObjectIdentifier {
        ObjectIdentifier(window)
    }

    func snapshot(of window: SimulatedWindow) -> WindowSnapshot? {
        WindowSnapshot(frame: window.frame, role: WindowSnapshot.windowRole)
    }

    func frame(of window: SimulatedWindow) -> CGRect? {
        window.frame
    }

    func setSize(_: CGSize, of _: SimulatedWindow) -> Bool {
        false
    }

    func setPosition(_: CGPoint, of _: SimulatedWindow) -> Bool {
        false
    }

    func withEnhancedUserInterfaceOff<Result>(pid _: Int32, _ body: () -> Result) -> Result {
        body()
    }
}
