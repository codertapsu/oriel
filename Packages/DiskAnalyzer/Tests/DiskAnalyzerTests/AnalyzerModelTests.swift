@testable import DiskAnalyzer
import Foundation
import OrielCore
import Testing

/// The window's model and the file lists' queries, without a window.
@MainActor
struct AnalyzerModelTests {
    private func model(with tree: ScanTree) throws -> DiskAnalyzerModel {
        let folder = try TemporaryFolder()
        let model = try DiskAnalyzerModel(
            settings: Fixtures.memorySettings(),
            store: ScanSnapshotStore(directory: folder.url)
        )
        model.target = ScanTarget(requestedPath: tree.rootPath, scanPath: tree.rootPath, displayName: "Root", firmlinks: .empty)
        model.phase = .ready(stopped: false)
        model.adopt(tree)
        return model
    }

    private let tree = Fixtures.tree([
        "Movies/trip.mov": 8_000_000,
        "Movies/Old/1999.avi": 3_000_000,
        "Code/app/main.swift": 2_000_000,
        "notes.pdf": 1_500_000,
    ], small: ["Code": (count: 12, size: 400_000)])

    @Test func cleanUpReadsAFolderOfTheScanFromIt() async throws {
        let model = try model(with: tree)
        let result = try #require(await model.adviseCleanup(of: "/Root/Movies", cancellation: CancellationFlag()))
        #expect(result.facts.bytes == 11_000_000)
        #expect(result.facts.children.map(\.name) == ["trip.mov", "Old"])
    }

    @Test func cleanUpScansAFolderOutsideTheScan() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        try folder.file("Cache/blob", size: 3_000_000)
        try folder.file("notes.txt", size: 100)
        let model = try DiskAnalyzerModel(settings: Fixtures.memorySettings(), store: ScanSnapshotStore(directory: folder.url))
        let result = try #require(await model.adviseCleanup(of: folder.path, cancellation: CancellationFlag()))
        #expect(result.facts.bytes >= 3_000_000)
        #expect(result.facts.cacheFolders.map(\.name) == ["Cache"])
        #expect(result.facts.names.contains("notes.txt"))
        #expect(await model.adviseCleanup(of: folder.path + "/notes.txt", cancellation: CancellationFlag()) == nil)
    }

    @Test func aPlanTakesEachItemOnceAndNeverTheRootOrABlock() throws {
        let model = try model(with: tree)
        let movies = try #require(Fixtures.index("Movies", in: tree))
        let trip = try #require(Fixtures.index("Movies/trip.mov", in: tree))
        let code = try #require(Fixtures.index("Code", in: tree))
        let small = try #require(tree.children(of: code).first { tree[$0].kind == .smallFiles })
        let plan = try #require(model.plan(.trash, nodes: [trip, movies, ScanTree.rootIndex, small]))
        #expect(plan.nodes == [movies])
        #expect(plan.bytes == 11_000_000)
        #expect(plan.operation.items.map(\.path) == ["/Root/Movies"])
        #expect(model.plan(.trash, nodes: [small]) == nil)
    }

    @Test func goingIntoAndOutOfFolders() throws {
        let model = try model(with: tree)
        let movies = try #require(Fixtures.index("Movies", in: tree))
        let trip = try #require(Fixtures.index("Movies/trip.mov", in: tree))
        model.open(movies)
        #expect(model.focus == movies)
        #expect(model.breadcrumbs == [ScanTree.rootIndex, movies])
        model.open(trip)
        #expect(model.focus == movies)
        #expect(model.selection == [trip])
        model.goUp()
        #expect(model.focus == ScanTree.rootIndex)
        #expect(model.selection == [movies])
        #expect(!model.canGoUp)
    }

    @Test func theFolderAndSelectionSurviveARenumberedTree() throws {
        let model = try model(with: tree)
        let movies = try #require(Fixtures.index("Movies", in: tree))
        let old = try #require(Fixtures.index("Movies/Old", in: tree))
        model.focus = movies
        model.selection = [old]
        var edited = tree
        try edited.remove(#require(Fixtures.index("Code", in: tree)))
        let compacted = edited.compacted()
        model.adopt(compacted)
        #expect(compacted.path(of: model.focus) == "/Root/Movies")
        #expect(model.selection.map(compacted.path(of:)) == ["/Root/Movies/Old"])
    }

    @Test func aFolderThatWentAwayLeavesTheNearestOneShown() throws {
        let model = try model(with: tree)
        let old = try #require(Fixtures.index("Movies/Old", in: tree))
        model.focus = old
        var edited = tree
        edited.remove(old)
        model.adopt(edited)
        #expect(model.focus == Fixtures.index("Movies", in: tree))
    }

    /// Oriel's own removals are not in the file system's events, so when one takes the link that carried a hard-linked
    /// file's size, the window reads the folder holding its other link again, and that link then carries it.
    @Test func removingTheCountedLinkCountsTheFileAtTheOther() async throws {
        let store = try TemporaryFolder()
        let folder = try TemporaryFolder()
        let original = try folder.file("a/original.bin", size: 4_000_000)
        let size = Fixtures.allocated(original)
        try folder.folder("b")
        #expect(link(original.path, folder.path + "/b/link.bin") == 0)
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        let model = try DiskAnalyzerModel(settings: Fixtures.memorySettings(), store: ScanSnapshotStore(directory: store.url))
        model.target = target
        model.phase = .ready(stopped: false)
        model.adopt(scanned.tree)
        model.summary = scanned.summary
        // The link kept one by one is the one that carries the size; the other is among its folder's smaller files.
        let counted = try #require(scanned.tree.files(under: ScanTree.rootIndex).first)
        try FileManager.default.removeItem(atPath: scanned.tree.path(of: counted))
        model.remove([counted])
        let deadline = ContinuousClock.now + .seconds(10)
        while model.tree?.contains(counted) != false || model.tree?.root.size != size, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.tree?.contains(counted) == false)
        #expect(model.tree?.root.size == size)
        #expect(model.tree?.root.fileCount == 1)
    }

    /// A scan of a whole volume adds up to its used space with Other space, what no file accounts for. A refresh sums it
    /// again, as the scan summed it, so the volume still adds up, and the summary follows.
    @Test func aRefreshSumsOtherSpaceAgain() async throws {
        let store = try TemporaryFolder()
        let folder = try TemporaryFolder()
        try folder.file("Open/a.bin", size: 1_000_000)
        var target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        let volume = Fixtures.volume(used: scanned.tree.root.size + 500_000_000)
        target.volume = volume
        let tree = DiskAnalyzerModel.addingVolumeBlocks(to: scanned.tree, volume: volume)
        #expect(tree.root.size == volume.usage.used)
        let model = try DiskAnalyzerModel(settings: Fixtures.memorySettings(), store: ScanSnapshotStore(directory: store.url))
        model.target = target
        model.phase = .ready(stopped: false)
        model.adopt(tree)
        model.summary = scanned.summary

        let added = try folder.file("Open/b.bin", size: 3_000_000)
        model.filesChanged(ScanWatcher.Change(folders: [folder.path + "/Open"], deepFolders: [], rootChanged: false))
        let deadline = ContinuousClock.now + .seconds(10)
        while model.summary?.files != 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        let refreshed = try #require(model.tree)
        let other = try #require(refreshed.children(of: ScanTree.rootIndex).first { refreshed[$0].kind == .unaccounted })
        #expect(refreshed.root.size == volume.usage.used)
        #expect(refreshed[other].size == 500_000_000 - Fixtures.allocated(added))
        #expect(model.summary?.files == 2)
        #expect(model.summary?.bytes == volume.usage.used)
    }

    @Test func namesAndPathsAsTheUserKnowsThem() throws {
        let model = try model(with: tree)
        let code = try #require(Fixtures.index("Code", in: tree))
        let small = try #require(tree.children(of: code).first { tree[$0].kind == .smallFiles })
        #expect(model.displayName(of: small) == "12 smaller files")
        #expect(model.displayPath(of: ScanTree.rootIndex) == "/Root")
        #expect(model.content == .scan)
        model.source = .volume("/Elsewhere")
        #expect(model.content == .welcome)
    }

    @Test func biggestFilesAreSortedAndCut() {
        var query = FileQuery(
            mode: .biggest,
            version: 0,
            folder: ScanTree.rootIndex,
            filter: FileFilter(),
            sort: FileSort(),
            search: "",
            lastOpenedCount: 0
        )
        let result = query.run(in: tree, lastOpened: [:])
        #expect(result.rows.map { tree.name(of: $0) } == ["trip.mov", "1999.avi", "main.swift", "notes.pdf"])
        #expect(result.matches == 4)
        #expect(result.bytes == 14_500_000)
        query.filter.minimumSize = 2_500_000
        #expect(query.run(in: tree, lastOpened: [:]).rows.count == 2)
    }

    @Test func searchResultsCountAFolderAndWhatIsInItOnce() {
        let query = FileQuery(
            mode: .search,
            version: 0,
            folder: ScanTree.rootIndex,
            filter: FileFilter(),
            sort: FileSort(),
            search: "movies",
            lastOpenedCount: 0
        )
        let tree = Fixtures.tree(["Movies/movies.txt": 2_000_000, "Movies/b.mov": 3_000_000])
        let result = query.run(in: tree, lastOpened: [:])
        #expect(result.matches == 2)
        #expect(result.bytes == 5_000_000)
    }
}
