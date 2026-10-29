import AppKit
import OrielCore
import OrielTestSupport
import Testing
@testable import WindowTiling

/// The real Accessibility path, read-only (ORIEL_TCC_TESTS=1): the focused window of the app in front is looked up and
/// read, never moved, resized or focused, and `AXEnhancedUserInterface` is only read. Titles are never read.
@Suite(.requiresTCC)
struct SystemAccessTests {
    @Test @MainActor func theFrontAppsFocusedWindowCanBeRead() throws {
        let app = try #require(NSWorkspace.shared.frontmostApplication)
        let displays = DisplayReader.current()
        #expect(!displays.isEmpty)
        let access = AXWindowAccess()
        guard case let .found(window) = access.focusedWindow(of: app.processIdentifier) else {
            print("TCC tiling: \(app.bundleIdentifier ?? "?") has no focused window; nothing to read")
            return
        }
        let snapshot = try #require(access.snapshot(of: window), "the app did not answer within 0.25 s")
        #expect(snapshot.frame.width > 0 && snapshot.frame.height > 0)
        #expect(DisplayArrangement.index(of: snapshot.frame, in: displays) != nil)
        #expect(access.frame(of: window) == snapshot.frame)
        #expect(access.key(of: window) == access.key(of: window))
        print(
            "TCC tiling: \(app.bundleIdentifier ?? "?") role \(snapshot.role ?? "-") subrole \(snapshot.subrole ?? "-"), "
                + "movable \(snapshot.canMove), resizable \(snapshot.canResize), full screen \(snapshot.isFullScreen), "
                + "\(displays.count) displays"
        )
    }
}
