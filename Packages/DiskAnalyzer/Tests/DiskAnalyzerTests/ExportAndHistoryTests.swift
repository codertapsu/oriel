@testable import DiskAnalyzer
import Foundation
import Testing

/// CSV export, scan snapshots and what grew between two of them.
struct ExportAndHistoryTests {
    @Test func csvFieldsAreQuotedOnlyWhenNeeded() {
        #expect(CSVExporter.field("plain") == "plain")
        #expect(CSVExporter.field("a, b") == "\"a, b\"")
        #expect(CSVExporter.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExporter.field("two\nlines") == "\"two\nlines\"")
        #expect(CSVExporter.field("=SUM(A1)") == "'=SUM(A1)")
        #expect(CSVExporter.field("-rf") == "'-rf")
    }

    @Test func csvHasAHeaderAndOneRowPerItem() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let tree = Fixtures.tree(["Movies/Trip, 2024.mov": 8_000_000], modified: ["Movies/Trip, 2024.mov": date])
        let movie = try #require(Fixtures.index("Movies/Trip, 2024.mov", in: tree))
        let movies = try #require(Fixtures.index("Movies", in: tree))
        let csv = CSVExporter.csv([movies, movie], in: tree)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("Path,Name,Kind,Size (bytes)"))
        #expect(lines[1] == "/Root/Movies,Movies,Folder,8000000,8000000,1,,,")
        #expect(lines[2] == "\"/Root/Movies/Trip, 2024.mov\",\"Trip, 2024.mov\",Videos,8000000,8000000,1,2023-11-14T22:13:20Z,,")
    }

    @Test func aSnapshotKeepsTheFoldersWorthFollowing() {
        let tree = Fixtures.tree([
            "Big/inner/a.bin": 300_000_000,
            "Big/b.bin": 200_000_000,
            "Small/c.bin": 1_000_000,
        ])
        let snapshot = ScanSnapshot.make(from: tree, rootPath: "/Root", displayName: "Root", date: Date(timeIntervalSince1970: 0))
        #expect(snapshot.totalBytes == 501_000_000)
        #expect(snapshot.folderSizes[""] == 501_000_000)
        #expect(snapshot.folderSizes["Big"] == 500_000_000)
        #expect(snapshot.folderSizes["Big/inner"] == 300_000_000)
        #expect(snapshot.folderSizes["Small"] == nil)
        #expect(snapshot.files == 3)
    }

    @Test func aSnapshotSurvivesEncoding() throws {
        let tree = Fixtures.tree(["Big/a.bin": 300_000_000])
        let snapshot = ScanSnapshot.make(from: tree, rootPath: "/Root", displayName: "Root", date: Date(timeIntervalSince1970: 100))
        let decoded = try JSONDecoder().decode(ScanSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(decoded == snapshot)
    }

    @Test func theDiffPointsAtTheFolderThatGrew() {
        let old = snapshot(["": 1000, "Users": 900, "Users/me": 800, "Users/me/Downloads": 100, "Applications": 100])
        let new = snapshot([
            "": 1600, "Users": 1500, "Users/me": 1400, "Users/me/Downloads": 700, "Applications": 100, "Users/me/Movies": 300,
        ])
        let diff = SnapshotDiff.between(old, new, minimumChange: 50)
        #expect(diff.totalDelta == 600)
        // Users and Users/me grew by 600, which Downloads (+600) explains; Movies is new.
        #expect(diff.changes.map(\.path) == ["Users/me/Downloads", "Users/me/Movies"])
        #expect(diff.changes.first?.delta == 600)
        #expect(diff.changes.last?.before == nil)
    }

    @Test func shrinkingFoldersComeAfterGrowingOnes() {
        let old = snapshot(["": 1000, "A": 500, "B": 100])
        let new = snapshot(["": 900, "A": 200, "B": 300])
        let diff = SnapshotDiff.between(old, new, minimumChange: 50)
        #expect(diff.changes.map(\.path) == ["B", "A"])
        #expect(diff.changes.map(\.delta) == [200, -300])
    }

    @Test func smallChangesAreLeftOut() {
        let diff = SnapshotDiff.between(snapshot(["": 1000, "A": 500]), snapshot(["": 1010, "A": 510]), minimumChange: 50)
        #expect(diff.changes.isEmpty)
    }

    private func snapshot(_ sizes: [String: Int64]) -> ScanSnapshot {
        ScanSnapshot(
            rootPath: "/",
            displayName: "Macintosh HD",
            date: Date(timeIntervalSince1970: 0),
            totalBytes: sizes[""] ?? 0,
            files: 0,
            folders: 0,
            folderSizes: sizes
        )
    }
}
