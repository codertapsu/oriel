import Foundation
import OrielCore
import Synchronization
import Testing

/// Every feature asks `ProAccess` before a Pro feature runs; a locked one shows what Pro adds instead (PLAN §19).
@MainActor
struct ProAccessTests {
    private let feature = ProFeature(id: "capture.instant", title: "Instant Capture", summary: "Annotate in place.", module: .capture)

    @Test func unlockedEverythingRuns() {
        let access = ProAccess()
        var asked: [String] = []
        access.onLocked = { asked.append($0.id) }
        #expect(access.check(feature))
        #expect(asked.isEmpty)
    }

    @Test func lockedItShowsWhatProAddsAndDoesNotRun() {
        let access = ProAccess(isUnlocked: false)
        var asked: [String] = []
        access.onLocked = { asked.append($0.id) }
        #expect(!access.check(feature))
        #expect(!access.allows(feature))
        #expect(asked == ["capture.instant"])
    }

    /// AppKit views follow the change through a notification, posted only when the state changes.
    @Test func aChangePostsOnce() {
        let access = ProAccess(isUnlocked: false)
        // The observer's block may run on any thread, so the count is guarded.
        let posts = Mutex(0)
        let token = NotificationCenter.default.addObserver(forName: ProAccess.didChangeNotification, object: access, queue: nil) { _ in
            posts.withLock { $0 += 1 }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        access.setUnlocked(true)
        access.setUnlocked(true)
        #expect(posts.withLock { $0 } == 1 && access.isUnlocked)
    }

    /// The app wires gated commands everywhere, so a locked Pro command never runs from a menu, shortcut or URL.
    @Test func aGatedCommandRunsOnlyWhenUnlocked() {
        let access = ProAccess(isUnlocked: false)
        access.onLocked = { _ in }
        var runs = 0
        let command = ToolCommand(id: "captureInstant", title: "Instant Capture", symbol: "bolt", group: .capture, proFeature: feature) {
            runs += 1
        }.gated(by: access)
        command.perform()
        #expect(runs == 0)
        access.setUnlocked(true)
        command.perform()
        #expect(runs == 1)
    }

    @Test func aFreeCommandIsLeftAsItIs() {
        let access = ProAccess(isUnlocked: false)
        var runs = 0
        let command = ToolCommand(id: "captureArea", title: "Capture Area", symbol: "rectangle", group: .capture) { runs += 1 }
        command.gated(by: access).perform()
        #expect(runs == 1)
    }
}
