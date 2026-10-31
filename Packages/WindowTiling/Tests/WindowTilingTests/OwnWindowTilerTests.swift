import AppKit
import OrielCore
import Testing
@testable import WindowTiling

/// Oriel's own window in front is arranged through AppKit on the main thread, never by the AX actor, which must not
/// ask Oriel itself (docs/os-quirks.md): the same layouts, in the same coordinates.
@MainActor
struct OwnWindowTilerTests {
    private static let start = CGRect(x: 300, y: 200, width: 700, height: 500)

    private func window(_ frame: CGRect, styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]) -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: true)
        window.setFrame(ScreenGeometry.cocoaRect(fromCG: frame, primaryHeight: Displays.primaryHeight), display: false)
        return window
    }

    private func tiler(_ window: NSWindow?) -> OwnWindowTiler {
        OwnWindowTiler(access: OwnWindowAccess(window: { window }, primaryHeight: { Displays.primaryHeight }))
    }

    private func frame(of window: NSWindow) -> CGRect {
        ScreenGeometry.cgRect(fromCocoa: window.frame, primaryHeight: Displays.primaryHeight)
    }

    @Test func itsWindowGetsTheLeftHalfAnotherAppsWindowWouldGet() {
        let window = window(Self.start)
        let tiler = tiler(window)
        #expect(tiler.arrange(.leftHalf, displays: [Displays.laptop], options: TilingOptions()) == .moved)
        #expect(frame(of: window) == CGRect(x: 0, y: 33, width: 756, height: 879))
    }

    @Test func restorePutsItBack() {
        let window = window(Self.start)
        let tiler = tiler(window)
        _ = tiler.arrange(.maximize, displays: [Displays.laptop], options: TilingOptions())
        #expect(tiler.arrange(.restore, displays: [Displays.laptop], options: TilingOptions()) == .moved)
        #expect(frame(of: window) == Self.start)
    }

    @Test func aWindowThatCannotResizeKeepsItsSize() {
        let window = window(Self.start, styleMask: [.titled, .closable])
        _ = tiler(window).arrange(.bottomRight, displays: [Displays.laptop], options: TilingOptions())
        #expect(frame(of: window) == CGRect(x: 812, y: 412, width: 700, height: 500))
    }

    /// AppKit's `setFrame(_:display:)` ignores a window's minimum and maximum sizes, which resizing by hand and
    /// Accessibility honour: Disk Space Analyzer's 880-point minimum holds when a third of the laptop's screen is
    /// narrower, and the window lines up with the third's edge, as another app's would.
    @Test func itsWindowKeepsItsMinimumSize() {
        let window = window(CGRect(x: 300, y: 200, width: 900, height: 600))
        window.minSize = CGSize(width: 880, height: 540)
        _ = tiler(window).arrange(.firstThird, displays: [Displays.laptop], options: TilingOptions())
        #expect(frame(of: window) == CGRect(x: 0, y: 33, width: 880, height: 879))
    }

    /// Most of Oriel's windows set the minimum of their content instead.
    @Test func itsWindowKeepsItsContentsMinimumSize() {
        let window = window(CGRect(x: 300, y: 200, width: 900, height: 600))
        window.contentMinSize = CGSize(width: 620, height: 380)
        _ = tiler(window).arrange(.firstThird, displays: [Displays.laptop], options: TilingOptions())
        #expect(frame(of: window) == CGRect(x: 0, y: 33, width: 620, height: 879))
    }

    @Test func itsWindowKeepsItsMaximumSize() {
        let window = window(Self.start)
        window.maxSize = CGSize(width: 800, height: 600)
        _ = tiler(window).arrange(.maximize, displays: [Displays.laptop], options: TilingOptions())
        #expect(frame(of: window) == CGRect(x: 356, y: 173, width: 800, height: 600))
    }

    @Test func withoutAWindowInFrontNothingMoves() {
        #expect(tiler(nil).arrange(.maximize, displays: [Displays.laptop], options: TilingOptions()) == .noWindow)
    }

    @Test func theAXActorNeverAsksOrielItself() {
        guard case .noWindow = AXWindowAccess().focusedWindow(of: OwnWindowTiler.ownPID) else {
            Issue.record("asked Oriel itself through Accessibility")
            return
        }
    }
}
