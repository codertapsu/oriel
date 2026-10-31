import Darwin
@testable import DiskAnalyzer
import Foundation
import Testing

/// The scanner on folders it creates in the temporary directory.
struct ScanEngineTests {
    private func allocated(_ url: URL) -> Int64 {
        var info = stat()
        return lstat(url.path, &info) == 0 ? Int64(info.st_blocks) * 512 : 0
    }

    private func scan(
        _ folder: TemporaryFolder,
        options: ScanOptions = ScanOptions(),
        mode: DirectoryReader.Mode = .automatic,
        cancellation: CancellationFlag = CancellationFlag(),
        progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }
    ) async -> ScanEngine.Outcome {
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        return await ScanEngine.scan(target, options: options, cancellation: cancellation, readerMode: mode, progress: progress)
    }

    @Test func nestedFoldersAddUpToTheAllocatedSizes() async throws {
        let folder = try TemporaryFolder()
        let big = try folder.file("Movies/Trips/trip.mov", size: 3_000_000)
        let medium = try folder.file("Movies/clip.mov", size: 1_500_000)
        let smalls = try (0 ..< 5).map { try folder.file("Docs/note\($0).txt", size: 5000) }
        try folder.folder("Empty")
        let outcome = await scan(folder)
        let tree = outcome.tree
        let expected = allocated(big) + allocated(medium) + smalls.reduce(0) { $0 + allocated($1) }
        #expect(tree.root.size == expected)
        #expect(tree.root.fileCount == 7)
        #expect(tree.root.folderCount == 4)
        let trip = try #require(tree.index(ofPath: big.path))
        #expect(tree[trip].kind == .file)
        #expect(tree[trip].category == .video)
        #expect(tree[trip].logicalSize == 3_000_000)
        let docs = try #require(tree.index(ofPath: folder.path + "/Docs"))
        let aggregate = try #require(tree.children(of: docs).first)
        #expect(tree[aggregate].kind == .smallFiles)
        #expect(tree[aggregate].fileCount == 5)
        #expect(outcome.summary.files == 7)
        #expect(outcome.summary.categories.count(of: .document) == 5)
        #expect(!outcome.summary.wasCancelled)
    }

    @Test func aHardLinkedFileIsCountedOnce() async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("a/original.bin", size: 4_000_000)
        try folder.folder("b")
        #expect(link(original.path, folder.path + "/b/link.bin") == 0)
        let outcome = await scan(folder)
        #expect(outcome.tree.root.size == allocated(original))
        #expect(outcome.summary.duplicateLinks == 1)
        #expect(outcome.tree.root.fileCount == 2)
    }

    /// A folder read again after a change counts a link of a file counted in another folder as a further link, as the
    /// scan did, and the folder that counted it goes on counting it: whichever folders are read again, one by one or
    /// all the way down from the top (none named), the file is counted once.
    @Test(arguments: [["a"], ["b"], ["a", "b"], []])
    func aRefreshCountsAHardLinkedFileOnce(_ changed: [String]) async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("a/original.bin", size: 4_000_000)
        try folder.folder("b")
        #expect(link(original.path, folder.path + "/b/link.bin") == 0)
        let first = await scan(folder)
        let shallow = try Set(changed.map { try #require(first.tree.index(ofPath: folder.path + "/" + $0)) })
        let refreshed = await ScanEngine.refresh(
            first.tree,
            folders: shallow,
            recursive: changed.isEmpty ? [ScanTree.rootIndex] : [],
            options: ScanOptions(),
            cancellation: CancellationFlag()
        )
        #expect(refreshed.tree.root.size == allocated(original))
        #expect(refreshed.tree.root.fileCount == 2)
    }

    /// When the link that carried a file's size goes, the file is counted at its other link, as a scan would count it,
    /// though only the folder it went from is read again.
    @Test func aFileIsCountedAtItsOtherLinkWhenTheCountedOneGoes() async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("a/original.bin", size: 4_000_000)
        let size = allocated(original)
        try folder.folder("b")
        #expect(link(original.path, folder.path + "/b/link.bin") == 0)
        let first = await scan(folder)
        let folderA = try #require(first.tree.index(ofPath: folder.path + "/a"))
        let folderB = try #require(first.tree.index(ofPath: folder.path + "/b"))
        // Which link carries the size depends on which thread read its folder first.
        let counted = first.tree[folderA].size > 0 ? folderA : folderB
        let other = counted == folderA ? folderB : folderA
        try FileManager.default.removeItem(atPath: counted == folderA ? original.path : folder.path + "/b/link.bin")
        let refreshed = await ScanEngine.refresh(
            first.tree, folders: [counted], recursive: [], options: ScanOptions(), cancellation: CancellationFlag()
        )
        #expect(refreshed.tree.root.size == size)
        #expect(refreshed.tree[other].size == size)
        #expect(refreshed.tree[counted].size == 0)
    }

    /// A folder moved with hard links inside is counted once whichever of the two folders is read first: here the one
    /// it went to, while its old copy is still in the scan, and only then the one it left.
    @Test func aFolderMovedWithItsLinksIsCountedOnce() async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("A/S/x.bin", size: 4_000_000)
        let size = allocated(original)
        #expect(link(original.path, folder.path + "/A/S/y.bin") == 0)
        try folder.folder("B")
        let first = await scan(folder)
        let origin = try #require(first.tree.index(ofPath: folder.path + "/A"))
        let destination = try #require(first.tree.index(ofPath: folder.path + "/B"))
        try FileManager.default.moveItem(atPath: folder.path + "/A/S", toPath: folder.path + "/B/S")
        let arrived = await ScanEngine.refresh(
            first.tree, folders: [destination], recursive: [], options: ScanOptions(), cancellation: CancellationFlag()
        )
        #expect(arrived.tree.root.size == size)
        let left = await ScanEngine.refresh(
            arrived.tree, folders: [origin], recursive: [], options: ScanOptions(), cancellation: CancellationFlag()
        )
        #expect(left.tree.root.size == size)
        #expect(left.tree[destination].size == size)
        #expect(left.tree.index(ofPath: folder.path + "/A/S") == nil)
    }

    @Test func symbolicLinksAreNeverFollowed() async throws {
        let outside = try TemporaryFolder()
        try outside.file("huge.bin", size: 5_000_000)
        let folder = try TemporaryFolder()
        let inside = try folder.file("Real/data.bin", size: 2_000_000)
        try FileManager.default.createSymbolicLink(atPath: folder.path + "/ToOutside", withDestinationPath: outside.path)
        try FileManager.default.createSymbolicLink(atPath: folder.path + "/ToReal", withDestinationPath: folder.path + "/Real")
        let outcome = await scan(folder)
        // The links themselves take no blocks; neither target is counted again through them.
        #expect(outcome.tree.root.size == allocated(inside))
        #expect(outcome.tree.root.folderCount == 1)
        #expect(outcome.tree.index(ofPath: folder.path + "/ToOutside/huge.bin") == nil)
    }

    /// A folder whose permissions keep the user out fails with `EACCES`, which Full Disk Access does not change: it is
    /// one an administrator can read.
    @Test func foldersThatCannotBeReadAreCountedAndMarkedWithWhy() async throws {
        let folder = try TemporaryFolder()
        try folder.file("Open/a.bin", size: 2_000_000)
        try folder.file("Locked/secret.bin", size: 2_000_000)
        #expect(chmod(folder.path + "/Locked", 0) == 0)
        defer { chmod(folder.path + "/Locked", 0o755) }
        let outcome = await scan(folder)
        #expect(outcome.summary.unreadableFolders == 1)
        #expect(outcome.summary.administratorFolders == 1)
        #expect(outcome.summary.protectedFolders == 0)
        #expect(outcome.summary.samples(.needsAdministrator) == [folder.path + "/Locked"])
        let locked = try #require(outcome.tree.index(ofPath: folder.path + "/Locked"))
        #expect(outcome.tree[locked].flags.isSuperset(of: [.unreadable, .needsAdministrator]))
        #expect(!outcome.tree[locked].flags.contains(.protectedByMacOS))
        #expect(outcome.tree[locked].size == 0)
    }

    @Test func theReasonFollowsTheError() {
        #expect(UnreadableReason(error: EACCES) == .needsAdministrator)
        #expect(UnreadableReason(error: EPERM) == .protectedByMacOS)
        #expect(UnreadableReason(error: EIO) == .other)
        for reason in [UnreadableReason.needsAdministrator, .protectedByMacOS, .other] {
            #expect(UnreadableReason(flags: reason.flags) == reason)
        }
        var tree = ScanTree(rootName: "Root", rootPath: "/Root")
        tree.setUnreadable(.needsAdministrator, at: ScanTree.rootIndex)
        tree.setUnreadable(.protectedByMacOS, at: ScanTree.rootIndex)
        #expect(tree.root.flags == [.unreadable, .protectedByMacOS])
    }

    @Test func aCancelledScanStopsAndSaysSo() async throws {
        let folder = try TemporaryFolder()
        for number in 0 ..< 300 {
            try folder.folder("f\(number)/inner")
        }
        let flag = CancellationFlag()
        flag.cancel()
        let before = await scan(folder, cancellation: flag)
        #expect(before.summary.wasCancelled)
        #expect(before.tree.count == 1)

        var options = ScanOptions()
        options.workerCount = 2
        options.progressInterval = .zero
        let midway = CancellationFlag()
        let outcome = await scan(folder, options: options, cancellation: midway) { _ in midway.cancel() }
        #expect(outcome.summary.wasCancelled)
        #expect(outcome.tree.root.folderCount < 600)
    }

    @Test func progressIsReportedWhileScanning() async throws {
        let folder = try TemporaryFolder()
        for number in 0 ..< 50 {
            try folder.file("f\(number)/a.bin", size: 2000)
        }
        var options = ScanOptions()
        options.progressInterval = .zero
        let reports = ProgressLog()
        _ = await scan(folder, options: options) { reports.add($0) }
        let last = try #require(reports.all.last)
        #expect(reports.all.count > 1)
        #expect(last.folders > 1)
        #expect(last.currentPath.hasPrefix(folder.path))
    }

    @Test func bothReadersSeeTheSameTree() async throws {
        let folder = try TemporaryFolder()
        try folder.file("A/big.bin", size: 2_500_000)
        try folder.file("A/B/small.txt", size: 300)
        try folder.file(".hidden/cache.db", size: 1_200_000)
        try folder.file("Tool.app/Contents/MacOS/Tool", size: 1_100_000)
        let original = try folder.file("C/linked.bin", size: 1_300_000)
        #expect(link(original.path, folder.path + "/A/linked-again.bin") == 0)
        let bulk = await scan(folder)
        let fallback = await scan(folder, mode: .foundationOnly)
        #expect(bulk.tree.root.size == fallback.tree.root.size)
        #expect(bulk.tree.root.fileCount == fallback.tree.root.fileCount)
        #expect(bulk.tree.root.folderCount == fallback.tree.root.folderCount)
        // Of the two links, the one a thread happens to read first is counted; the other falls into its folder's smaller
        // files. So the links and the aggregates are compared apart.
        let links: Set<String> = [folder.path + "/C/linked.bin", folder.path + "/A/linked-again.bin"]
        let names = { (tree: ScanTree) in
            tree.descendants(of: ScanTree.rootIndex) { _ in true }.filter { tree[$0].kind != .smallFiles }
                .map { tree.displayPath(of: $0) }.filter { !links.contains($0) }.sorted()
        }
        #expect(names(bulk.tree) == names(fallback.tree))
        for tree in [bulk.tree, fallback.tree] {
            #expect(links.count { tree.index(ofPath: $0) != nil } == 1)
        }
        let tool = try #require(bulk.tree.index(ofPath: folder.path + "/Tool.app/Contents/MacOS/Tool"))
        #expect(bulk.tree[tool].category == .application)
        #expect(try bulk.tree[#require(bulk.tree.index(ofPath: folder.path + "/Tool.app"))].kind == .package)
    }

    @Test func exclusionsAndHiddenFilesFollowTheSettings() async throws {
        let folder = try TemporaryFolder()
        try folder.file("node_modules/pkg/index.js", size: 2_000_000)
        try folder.file(".cache/blob", size: 2_000_000)
        let kept = try folder.file("src/app.bin", size: 2_000_000)
        var options = ScanOptions()
        options.exclusions = ExclusionRules(["node_modules"], home: NSHomeDirectory())
        options.includesHiddenFiles = false
        let outcome = await scan(folder, options: options)
        #expect(outcome.tree.root.size == allocated(kept))
        let modules = try #require(outcome.tree.index(ofPath: folder.path + "/node_modules"))
        #expect(outcome.tree[modules].flags.contains(.excluded))
        #expect(outcome.tree.index(ofPath: folder.path + "/.cache") == nil)
    }

    @Test func aRefreshPicksUpWhatChanged() async throws {
        let folder = try TemporaryFolder()
        let stays = try folder.file("Work/stays.bin", size: 2_000_000)
        let goes = try folder.file("Work/goes.bin", size: 3_000_000)
        try folder.file("Work/Deep/deep.bin", size: 1_000_000)
        let first = await scan(folder)
        let work = try #require(first.tree.index(ofPath: folder.path + "/Work"))
        try FileManager.default.removeItem(at: goes)
        let added = try folder.file("Work/New/added.bin", size: 4_000_000)
        let refreshed = await ScanEngine.refresh(
            first.tree,
            folders: [work],
            recursive: [],
            options: ScanOptions(),
            cancellation: CancellationFlag()
        )
        let tree = refreshed.tree
        let deep = try #require(tree.index(ofPath: folder.path + "/Work/Deep/deep.bin"))
        #expect(tree.index(ofPath: goes.path) == nil)
        #expect(tree.index(ofPath: added.path) != nil)
        #expect(tree.root.size == allocated(stays) + allocated(added) + tree[deep].size)
        #expect(tree.root.fileCount == 3)
    }
}

/// Collects progress reports from the scanning threads.
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [ScanProgress] = []

    func add(_ report: ScanProgress) {
        lock.withLock { reports.append(report) }
    }

    var all: [ScanProgress] {
        lock.withLock { reports }
    }
}
