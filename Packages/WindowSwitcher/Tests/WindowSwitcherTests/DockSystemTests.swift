import AppKit
import CoreGraphics
import OrielTestSupport
import Testing
@testable import WindowSwitcher

/// The real Dock, read only (ORIEL_TCC_TESTS=1): its icons through Accessibility. Nothing is shown, clicked or changed;
/// the observer is removed again. The summary prints counts, never titles.
@Suite(.requiresTCC)
struct DockSystemTests {
    @Test @MainActor func theDockListsItsIconsWithFramesOnScreen() async throws {
        let pid = try #require(
            NSRunningApplication.runningApplications(withBundleIdentifier: DockAccessibility.bundleIdentifier).first?.processIdentifier
        )
        let dock = DockAccessibility()
        #expect(await dock.start(pid: pid), "the Dock did not answer: is Accessibility granted to the test runner?")
        let displays = DisplayDirectory.current().map(\.bounds)
        let layout = try #require(await dock.layout(displays: displays))
        await dock.stop()
        let apps = layout.items.filter { $0.kind == .application }
        #expect(!apps.isEmpty, "every Dock has Finder")
        #expect(apps.allSatisfy { $0.url != nil && $0.frame.width > 0 })
        let screens = displays.reduce(CGRect.null) { $0.union($1) }
        #expect(layout.items.allSatisfy { screens.intersects($0.frame) })
        print("Dock: \(layout.items.count) icons, \(apps.count) apps, \(apps.filter(\.isRunning).count) running, edge \(layout.edge)")
    }
}
