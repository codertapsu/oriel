@testable import DiskAnalyzer
import Foundation
import OrielCore
import Testing

/// Read as Administrator in the window's model, as far as it goes in a test. This process has no helper (no launchd
/// property list in its bundle, no team in its signature), so the helper is never registered or reached here.
@MainActor
struct ReadAsAdministratorTests {
    /// A model with a scan of a folder only an administrator can open.
    private func model(settings: SettingsStore, store: TemporaryFolder) throws -> DiskAnalyzerModel {
        let model = DiskAnalyzerModel(settings: settings, store: ScanSnapshotStore(directory: store.url))
        var tree = Fixtures.tree(["Open/a.bin": 2_000_000, "Locked/": 0])
        try tree.setUnreadable(.needsAdministrator, at: #require(Fixtures.index("Locked", in: tree)))
        var summary = ScanSummary()
        summary.recountUnreadable(in: tree)
        model.target = ScanTarget(requestedPath: tree.rootPath, scanPath: tree.rootPath, displayName: "Root", firmlinks: .empty)
        model.phase = .ready(stopped: false)
        model.adopt(tree)
        model.summary = summary
        return model
    }

    private func waitWhileReading(_ model: DiskAnalyzerModel) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while model.isReadingAsAdministrator, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isReadingAsAdministrator)
    }

    /// Remove Helper in Settings changes neither the window's idea of the helper nor anything that makes it look again,
    /// and forgets which build registered it. The next scan's read must ask macOS, find it gone, and leave it gone,
    /// rather than take the build it no longer knows for an update and register it again.
    @Test func aHelperRemovedInSettingsIsNotRegisteredAgain() async throws {
        let store = try TemporaryFolder()
        let settings = try Fixtures.memorySettings()
        let model = try model(settings: settings, store: store)
        let forgotten = PrivilegedReader.build + ".removed"
        settings[DiskSettings.helperBuild] = forgotten
        model.helperStatus = .allowed // what the window saw before the helper was removed
        model.readAsAdministratorAfterScan()
        try await waitWhileReading(model)
        #expect(settings[DiskSettings.helperBuild] == forgotten)
        #expect(model.helperStatus == .unavailable)
    }
}
