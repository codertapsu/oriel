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

    /// A refresh counts again the folders it could not read, so the note offering Read as Administrator follows the
    /// scan: one that appeared since, closed to the user, is counted.
    @Test func aRefreshCountsTheFoldersOnlyAnAdministratorCanOpen() async throws {
        let store = try TemporaryFolder()
        let folder = try TemporaryFolder()
        try folder.file("Open/a.bin", size: 1_000_000)
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        let model = try DiskAnalyzerModel(settings: Fixtures.memorySettings(), store: ScanSnapshotStore(directory: store.url))
        model.target = target
        model.phase = .ready(stopped: false)
        model.adopt(scanned.tree)
        model.summary = scanned.summary
        try folder.file("Locked/secret.bin", size: 2_000_000)
        #expect(chmod(folder.path + "/Locked", 0) == 0)
        defer { chmod(folder.path + "/Locked", 0o755) }

        model.filesChanged(ScanWatcher.Change(folders: [folder.path], deepFolders: [], rootChanged: false))
        let deadline = ContinuousClock.now + .seconds(10)
        while model.summary?.administratorFolders != 1, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.summary?.administratorFolders == 1)
        #expect(model.summary?.samples(.needsAdministrator) == [folder.path + "/Locked"])
    }
}
