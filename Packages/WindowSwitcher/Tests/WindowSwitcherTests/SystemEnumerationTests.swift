import CoreGraphics
import Foundation
import OrielCore
import OrielTestSupport
import PrivateAPIs
import Testing
@testable import WindowSwitcher

/// The real system, read-only (ORIEL_TCC_TESTS=1): Accessibility, CGWindowList and SkyLight are only read.
/// Nothing is focused, raised, moved, closed or minimized, no event tap starts and no hot key changes. The
/// summaries print counts, never window titles.
@Suite(.requiresTCC)
struct SystemEnumerationTests {
    /// While the screen is locked, Accessibility lists no real windows (macOS 27.0.1: app and scroll-area
    /// elements without window ids), so an empty list is then the right answer.
    static var isScreenLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    @Test @MainActor func theStoreListsRealWindowsSanely() async {
        let source = SystemWindowSource(observesChanges: false)
        let store = WindowStore(source: source)
        let clock = ContinuousClock()
        let start = clock.now
        await store.bootstrap()
        let elapsed = clock.now - start
        let entries = await store.entries
        await source.stop()

        let locked = Self.isScreenLocked
        #expect(!entries.isEmpty || locked, "no windows at all: is Accessibility granted to the test runner?")
        #expect(Set(entries.map(\.id)).count == entries.count, "duplicate window ids")
        let server = Dictionary(ServerWindowList.current().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in entries {
            let info = entry.info
            #expect(info.id != 0 && info.pid > 0 && !info.appName.isEmpty)
            #expect(!info.title.isEmpty, "titles fall back to the app name")
            #expect(info.frame.width >= 50 && info.frame.height >= 50, "a helper window got through")
            // Every window is one the server knows, at layer 0: no menu bar, status item or panel.
            if let record = server[info.id] {
                #expect(record.layer == 0)
                #expect(record.pid == info.pid)
            }
            if !info.isOnCurrentSpace, !info.isMinimized, !info.isHidden, !info.isFullScreen {
                #expect(info.spaceIndex != nil || !PrivateAPIs.shared.canReadSpaces)
            }
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        #expect(!entries.contains { $0.info.pid == ownPID }, "the test runner has no windows")
        let apps = Set(entries.map(\.info.pid)).count
        let otherSpaces = entries.filter { !$0.info.isOnCurrentSpace }.count
        let minimized = entries.filter(\.info.isMinimized).count
        let hidden = entries.filter(\.info.isHidden).count
        let fullScreen = entries.filter(\.info.isFullScreen).count
        let inert = entries.filter { !$0.isActionable }.count
        print(
            "TCC enumeration\(locked ? " (screen locked)" : ""): \(entries.count) windows of \(apps) apps in \(elapsed); "
                + "other Spaces \(otherSpaces), minimized \(minimized), hidden \(hidden), full screen \(fullScreen), "
                + "without AX element \(inert)"
        )
    }

    @Test @MainActor func theModuleListsWithoutBeingActivated() async {
        let module = WindowSwitcherModule()
        let all = await module.windows(includeOtherSpaces: true)
        let current = await module.windows(includeOtherSpaces: false)
        #expect(!all.isEmpty || Self.isScreenLocked)
        #expect(Set(current.map(\.id)).isSubset(of: Set(all.map(\.id))))
        let allCurrent = current.allSatisfy(\.isOnCurrentSpace)
        #expect(allCurrent)
        #expect(!module.isRunning)
    }

    @Test func skyLightDescribesEveryDisplay() throws {
        let displays = DisplayDirectory.current()
        #expect(!displays.isEmpty)
        #expect(displays.allSatisfy { $0.uuid != nil })
        let snapshot = try #require(SpaceReader.snapshot(for: [], displays: displays, apis: .shared))
        #expect(!snapshot.displays.isEmpty)
        for display in snapshot.displays {
            #expect(display.spaceIDs.contains(display.currentSpaceID))
        }
        let mapped = snapshot.displays.compactMap(\.displayID).count
        print("TCC Spaces: \(displays.count) displays, \(snapshot.displays.count) SkyLight displays (\(mapped) mapped), "
            + "\(snapshot.displays.map(\.spaceIDs.count)) Spaces each")
    }

    @Test func theCommandTabHotKeysAreFoundByEnumeration() {
        // Read-only: CGSGetSymbolicHotKeyValue only; nothing is disabled.
        let keys = PrivateAPIs.shared.symbolicHotKeys()
        let commandTab = ShortcutSpec(holdModifiers: .command, nextKey: KeyCode.tab, reverseModifier: .shift)
        let ids = CommandTabTakeover.hotKeyIDs(in: keys, for: [commandTab])
        #expect(!ids.isEmpty, "no ⌘⇥ symbolic hot key is bound and enabled")
        #expect(keys.contains { $0.id == 1 && $0.virtualKeyCode == KeyCode.tab })
        print("TCC hot keys: \(keys.count) bound; ⌘⇥ takeover would disable \(ids)")
    }
}
