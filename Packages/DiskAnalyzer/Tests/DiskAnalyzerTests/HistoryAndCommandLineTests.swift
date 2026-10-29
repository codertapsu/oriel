@testable import DiskAnalyzer
import Foundation
import OrielCore
import Testing

/// Remembered scans, and the `oriel disk` verbs on folders the tests create.
@MainActor
struct HistoryAndCommandLineTests {
    private func record(_ root: String, daysAgo: Double) -> ScanRecord {
        ScanRecord(ScanSnapshot(
            rootPath: root,
            displayName: root,
            date: Date().addingTimeInterval(-daysAgo * 86400),
            totalBytes: 1,
            files: 1,
            folders: 1,
            folderSizes: [:]
        ))
    }

    @Test func recentScansShowTheNewestOfEachFolder() {
        let records = [record("/a", daysAgo: 3), record("/b", daysAgo: 1), record("/a", daysAgo: 0.5), record("/c", daysAgo: 9)]
        #expect(ScanRecord.latestPerRoot(records, limit: 2).map(\.rootPath) == ["/a", "/b"])
    }

    @Test func pruningKeepsTheNewestPerFolderAndOverall() {
        let records = (0 ..< 8).map { record("/a", daysAgo: Double($0)) } + [record("/b", daysAgo: 0)]
        let dropped = ScanRecord.pruned(records, perRoot: 5, total: 5)
        let kept = records.filter { !dropped.contains($0.id) }
        #expect(kept.count == 5)
        #expect(kept.contains { $0.rootPath == "/b" })
        #expect(kept.filter { $0.rootPath == "/a" }.count == 4)
    }

    @Test func theStoreRemembersAndForgetsScans() async throws {
        let folder = try TemporaryFolder()
        let store = ScanSnapshotStore(directory: folder.url.appending(path: "Scans"))
        let tree = Fixtures.tree(["Big/a.bin": 300_000_000])
        let first = ScanSnapshot.make(from: tree, rootPath: "/Root", displayName: "Root", date: Date().addingTimeInterval(-60))
        let second = ScanSnapshot.make(from: tree, rootPath: "/Root", displayName: "Root", date: Date())
        await store.save(first)
        let records = await store.save(second)
        #expect(records.count == 2)
        #expect(await store.previous(of: "/Root", excluding: second.id)?.id == first.id)
        let reopened = ScanSnapshotStore(directory: folder.url.appending(path: "Scans"))
        #expect(await reopened.records().count == 2)
        #expect(await reopened.snapshot(first.id) == first)
        #expect(await reopened.remove(rootPath: "/Root").isEmpty)
        #expect(await reopened.snapshot(first.id) == nil)
    }

    @Test func theReportListsTheLargestItemsAndFiles() throws {
        let tree = Fixtures.tree(["Movies/a.mov": 9_000_000, "Movies/b.mov": 3_000_000, "notes.pdf": 2_000_000])
        let target = ScanTarget(requestedPath: "/Root", scanPath: "/Root", displayName: "Root", firmlinks: .empty)
        var summary = ScanSummary()
        summary.files = 3
        summary.folders = 1
        let report = ScanReport(tree: tree, summary: summary, target: target, top: 2)
        #expect(report.text.contains("Largest items:"))
        #expect(report.text.contains("Movies"))
        #expect(report.text.contains("/Root/Movies/a.mov"))
        let json = report.json
        #expect(json["bytes"] as? Int64 == 14_000_000)
        let files = try #require(json["largestFiles"] as? [[String: Any]])
        #expect(files.count == 2)
        #expect(files.first?["path"] as? String == "/Root/Movies/a.mov")
    }

    private func request(_ arguments: [String], _ options: [String: String] = [:]) -> IPCRequest {
        IPCRequest(verb: "disk.scan", arguments: arguments, options: options)
    }

    @Test func diskScanReportsAFolder() async throws {
        let folder = try TemporaryFolder()
        try folder.file("Videos/clip.mov", size: 4_000_000)
        try folder.file("notes.txt", size: 300)
        let settings = try Fixtures.memorySettings()
        let text = await DiskCommandLine.scan(request([folder.path]), settings: settings)
        #expect(text.status == 0)
        #expect(text.output.contains("clip.mov"))
        let json = await DiskCommandLine.scan(request([folder.path], ["json": "true", "top": "1"]), settings: settings)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.output.utf8)) as? [String: Any])
        #expect(object["files"] as? Int == 2)
        #expect((object["largestItems"] as? [Any])?.count == 1)
    }

    @Test func diskScanRefusesWhatItCannotScan() async throws {
        let settings = try Fixtures.memorySettings()
        #expect(await DiskCommandLine.scan(request([]), settings: settings).status == 64)
        #expect(await DiskCommandLine.scan(request(["relative/path"]), settings: settings).status == 64)
        #expect(await DiskCommandLine.scan(request(["/tmp"], ["top": "0"]), settings: settings).status == 64)
        #expect(await DiskCommandLine.scan(request(["/no/such/folder/\(UUID().uuidString)"]), settings: settings).status == 1)
    }
}
