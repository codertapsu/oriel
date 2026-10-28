import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// The pure parts of the system source: CGWindowList dictionaries, SkyLight display names, Space placement,
/// notification mapping and settings decoding.
struct SourceParsingTests {
    @Test func serverDictionariesParseAndJunkIsSkipped() {
        let list: [[String: Any]] = [
            [
                "kCGWindowNumber": 42, "kCGWindowOwnerPID": 638, "kCGWindowLayer": 0, "kCGWindowAlpha": 1.0,
                "kCGWindowIsOnscreen": true, "kCGWindowName": "Documents",
                "kCGWindowBounds": ["X": 10.0, "Y": 20.0, "Width": 800.0, "Height": 600.0],
            ],
            ["kCGWindowNumber": 43, "kCGWindowOwnerPID": 638, "kCGWindowLayer": 24],
            ["kCGWindowOwnerPID": 1],
        ]
        let parsed = ServerWindowList.parse(list)
        #expect(parsed.count == 2)
        #expect(parsed[0] == ServerWindowRecord(
            id: 42, pid: 638, frame: CGRect(x: 10, y: 20, width: 800, height: 600), alpha: 1, isOnScreen: true, title: "Documents"
        ))
        #expect(parsed[1].layer == 24 && parsed[1].frame == .zero && !parsed[1].isOnScreen && parsed[1].title == nil)
    }

    @Test func skyLightDisplayNamesMapToDisplays() {
        let displays = [
            DisplayInfo(id: 1, uuid: "37D8832A-2D66-02CA-B9F7-8F30A301B230", bounds: .zero),
            DisplayInfo(id: 3, uuid: "FA7EC8AB-8121-4A55-B432-22CD130EE508", bounds: .zero),
        ]
        #expect(SpaceReader.displayID(for: "fa7ec8ab-8121-4a55-b432-22cd130ee508", among: displays) == 3)
        #expect(SpaceReader.displayID(for: "unknown", among: displays) == nil)
        // "Displays have separate Spaces" off: one "Main" entry spans every display.
        #expect(SpaceReader.displayID(for: "Main", among: displays) == nil)
        #expect(SpaceReader.displayID(for: "Main", among: [displays[0]]) == 1)
    }

    @Test func placementsUseTheVisibleSpaceAndItsIndex() {
        let snapshot = SpaceSnapshot(displays: [
            SpaceSnapshot.Display(displayID: 1, currentSpaceID: 1, spaceIDs: [1, 4, 9], fullScreenSpaceIDs: [9]),
            SpaceSnapshot.Display(displayID: 2, currentSpaceID: 6, spaceIDs: [6, 7]),
        ])
        #expect(SpacePlacement.resolve(spaceIDs: [4], in: snapshot) == SpacePlacement(isOnCurrentSpace: false, spaceIndex: 2, displayID: 1))
        #expect(SpacePlacement.resolve(spaceIDs: [9], in: snapshot).isFullScreenSpace)
        #expect(SpacePlacement.resolve(spaceIDs: [7], in: snapshot) == SpacePlacement(isOnCurrentSpace: false, spaceIndex: 2, displayID: 2))
        // On every Space ("Assign to all desktops"): it counts as visible, on the visible one.
        #expect(SpacePlacement.resolve(spaceIDs: [4, 1, 9], in: snapshot) == SpacePlacement(
            isOnCurrentSpace: true,
            spaceIndex: 1,
            displayID: 1
        ))
        #expect(SpacePlacement.resolve(spaceIDs: [], in: snapshot) == SpacePlacement())
        #expect(SpacePlacement.resolve(spaceIDs: [4], in: nil) == SpacePlacement())
        #expect(SpacePlacement.resolve(spaceIDs: [99], in: snapshot) == SpacePlacement(isOnCurrentSpace: false))
    }

    @Test func axNotificationsBecomeEvents() {
        #expect(AXNotificationRelay.event(for: kAXWindowCreatedNotification, pid: 5) == .windowsChanged(5))
        #expect(AXNotificationRelay.event(for: kAXUIElementDestroyedNotification, pid: 5) == .windowsChanged(5))
        #expect(AXNotificationRelay.event(for: kAXTitleChangedNotification, pid: 5) == .windowsChanged(5))
        #expect(AXNotificationRelay.event(for: kAXWindowMiniaturizedNotification, pid: 5) == .windowsChanged(5))
        #expect(AXNotificationRelay.event(for: kAXFocusedWindowChangedNotification, pid: 5) == .focusedWindowChanged(5))
        #expect(AXNotificationRelay.event(for: kAXApplicationActivatedNotification, pid: 5) == .appActivated(5))
        #expect(AXNotificationRelay.event(for: kAXApplicationHiddenNotification, pid: 5) == .appHidden(5))
        #expect(AXNotificationRelay.event(for: "AXSomethingElse", pid: 5) == nil)
        let registered = Set(AXNotificationRelay.applicationNotifications + AXNotificationRelay.windowNotifications)
        // PLAN §6.5: created, destroyed, focused, moved, resized, title changed, minimized, deminimized.
        let required = [
            kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification, kAXWindowResizedNotification, kAXTitleChangedNotification,
            kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        ]
        for name in required {
            #expect(registered.contains(name), "\(name) is not observed")
        }
    }

    @Test func workspaceNotificationsBecomeEvents() {
        #expect(WorkspaceObserver.event(for: NSWorkspace.didLaunchApplicationNotification, pid: 9) == .appLaunched(9))
        #expect(WorkspaceObserver.event(for: NSWorkspace.didTerminateApplicationNotification, pid: 9) == .appTerminated(9))
        #expect(WorkspaceObserver.event(for: NSWorkspace.didActivateApplicationNotification, pid: 9) == .appActivated(9))
        #expect(WorkspaceObserver.event(for: NSWorkspace.didHideApplicationNotification, pid: 9) == .appHidden(9))
        #expect(WorkspaceObserver.event(for: NSWorkspace.didUnhideApplicationNotification, pid: 9) == .appUnhidden(9))
        #expect(WorkspaceObserver.event(for: NSWorkspace.activeSpaceDidChangeNotification, pid: 9) == nil)
    }

    @Test func pendingWorkMergesBursts() {
        var work = PendingWork()
        for _ in 0 ..< 10 {
            work.add(.windowsChanged(4), refused: [])
        }
        work.add(.focusedWindowChanged(4), refused: [])
        work.add(.focusedWindowChanged(5), refused: [])
        work.add(.focusedWindowChanged(4), refused: [])
        work.add(.appActivated(7), refused: [7])
        #expect(work.pids == [4, 7])
        #expect(work.focusPIDs == [5, 4, 7])
        #expect(work.server && !work.allApps)
        work.add(.appTerminated(4), refused: [])
        #expect(work.pids == [7] && work.focusPIDs == [5, 7] && work.terminated == [4])
        work.add(.activeSpaceChanged, refused: [])
        #expect(work.allApps)
        var resumed = PendingWork()
        resumed.add(.sessionResumed, refused: [])
        #expect(resumed.applications && resumed.allApps && resumed.server)
    }

    @Test func shortcutsDecodeOldSettingsAndMatchExactModifiers() throws {
        let decoded = try JSONDecoder().decode(ShortcutSpec.self, from: Data(#"{"holdModifiers":8,"nextKey":48}"#.utf8))
        #expect(decoded.trigger == KeyCombo(keyCode: KeyCode.tab, modifiers: .command))
        #expect(decoded.isEnabled && decoded.releaseBehavior == .switchOnRelease && decoded.filter == WindowFilter())
        let shortcut = ShortcutSpec.optionTab
        #expect(shortcut.direction(keyCode: KeyCode.tab, modifiers: .option) == .forward)
        #expect(shortcut.direction(keyCode: KeyCode.tab, modifiers: [.option, .shift]) == .backward)
        #expect(shortcut.direction(keyCode: KeyCode.tab, modifiers: [.option, .control]) == nil)
        #expect(shortcut.direction(keyCode: KeyCode.grave, modifiers: .option) == nil)
        let data = try JSONEncoder().encode([shortcut])
        #expect(try JSONDecoder().decode([ShortcutSpec].self, from: data) == [shortcut])
    }

    @Test func aReverseModifierInsideTheHoldModifiersIsDropped() {
        var shortcut = ShortcutSpec(holdModifiers: [.option, .shift], nextKey: KeyCode.tab, reverseModifier: .shift)
        #expect(shortcut.effectiveReverseModifier == nil && shortcut.reverseTrigger == nil)
        #expect(shortcut.normalized().reverseModifier == nil)
        shortcut.trigger = KeyCombo(keyCode: KeyCode.grave, modifiers: .command)
        #expect(shortcut.nextKey == KeyCode.grave && shortcut.holdModifiers == .command)
        #expect(SwitcherConfiguration.sanitized(Array(repeating: .optionTab, count: 12)).count == ShortcutSpec.maximumCount)
    }

    @Test func theDefaultConfigurationIsOptionTab() {
        let configuration = SwitcherConfiguration()
        #expect(configuration.shortcuts == [.optionTab])
        #expect(configuration.triggerKeys == [KeyCode.tab])
        #expect(SwitcherSettingKeys.shortcuts.defaultValue == [.optionTab])
        #expect(SwitcherSettingKeys.style.defaultValue == .thumbnails)
    }
}
