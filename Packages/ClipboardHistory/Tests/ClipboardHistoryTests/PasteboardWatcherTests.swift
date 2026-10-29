import AppKit
@testable import ClipboardHistory
import Testing

/// A fake change count and private notification centers, so nothing here depends on the real clipboard.
@MainActor
struct PasteboardWatcherTests {
    private final class Pasteboard {
        var changeCount = 1
        var ownWrite: Int?
    }

    private func watcher(_ pasteboard: Pasteboard, workspace: NotificationCenter, local: NotificationCenter) -> PasteboardWatcher {
        PasteboardWatcher(
            changeCount: { pasteboard.changeCount },
            ownWriteChangeCount: { pasteboard.ownWrite },
            watchesKeys: { false },
            workspaceCenter: workspace,
            localCenter: local,
            delays: [.milliseconds(1)]
        )
    }

    @Test func reportsOtherAppsChangesOnceAndSkipsOrielsOwn() {
        let pasteboard = Pasteboard()
        let watcher = watcher(pasteboard, workspace: NotificationCenter(), local: NotificationCenter())
        var reported: [Int] = []
        watcher.onChange = { reported.append($0) }
        watcher.start()
        defer { watcher.stop() }
        watcher.checkNow()
        #expect(reported.isEmpty)
        pasteboard.changeCount = 2
        watcher.checkNow()
        watcher.checkNow()
        #expect(reported == [2])
        pasteboard.changeCount = 3
        pasteboard.ownWrite = 3
        watcher.checkNow()
        #expect(reported == [2])
    }

    @Test func anotherAppComingToTheFrontTriggersACheck() {
        let pasteboard = Pasteboard()
        let workspace = NotificationCenter()
        let local = NotificationCenter()
        let watcher = watcher(pasteboard, workspace: workspace, local: local)
        var reported: [Int] = []
        watcher.onChange = { reported.append($0) }
        watcher.start()
        pasteboard.changeCount = 5
        workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        #expect(reported == [5])
        pasteboard.changeCount = 6
        local.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(reported == [5, 6])
        watcher.stop()
        pasteboard.changeCount = 7
        workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        watcher.checkNow()
        #expect(reported == [5, 6])
    }

    @Test func aScheduledCheckRunsAfterItsDelay() async throws {
        let pasteboard = Pasteboard()
        let watcher = watcher(pasteboard, workspace: NotificationCenter(), local: NotificationCenter())
        var reported: [Int] = []
        watcher.onChange = { reported.append($0) }
        watcher.start()
        defer { watcher.stop() }
        pasteboard.changeCount = 9
        watcher.scheduleCheck()
        #expect(reported.isEmpty)
        try await Task.sleep(for: .milliseconds(100))
        #expect(reported == [9])
    }
}
