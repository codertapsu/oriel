import AppKit
@testable import DiskAnalyzer
import Foundation
import Testing

/// Closing the window frees it, its views and the open scan (PLAN §9: a scan's memory is kept only while the window is
/// open). A window that is never shown goes through every view and then closes; a retain cycle would keep the
/// controllers, and through them the tree, after Oriel's window has gone.
@MainActor
struct WindowLifecycleTests {
    @Test func closingTheWindowFreesItItsViewsAndTheScan() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let tree = Fixtures.tree(["Movies/trip.mov": 8_000_000, "Code/app/main.swift": 2_000_000, "notes.pdf": 1_500_000])
        let model = try DiskAnalyzerModel(settings: Fixtures.memorySettings(), store: ScanSnapshotStore(directory: folder.url))
        model.target = ScanTarget(requestedPath: tree.rootPath, scanPath: tree.rootPath, displayName: "Root", firmlinks: .empty)
        model.phase = .ready(stopped: false)
        model.adopt(tree)
        weak var controller: DiskWindowController?
        weak var window: NSWindow?
        weak var content: NSViewController?
        do {
            let opened = DiskWindowController(model: model)
            controller = opened
            window = opened.window
            content = opened.window?.contentViewController
            for view in DiskView.allCases {
                model.view = view
                await Task.yield()
            }
            opened.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        }
        // The views' observation hops end on the next turns of the main actor.
        try await Task.sleep(for: .milliseconds(200))
        #expect(controller == nil && window == nil && content == nil)
        #expect(model.tree == nil)
    }
}
