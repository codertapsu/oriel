import Darwin
@testable import DiskAnalyzer
import Foundation
import Synchronization
import Testing

/// Copies, moves, removals and Undo, on folders the tests create, with a Trash of their own: nothing ever reaches the
/// user's Trash.
struct FileOperatorTests {
    /// Moves items into a folder of the test's own, as the Trash would, and says where they went.
    private struct FolderTrash: Trashing {
        let folder: URL

        func trash(_ url: URL) throws -> URL? {
            let destination = folder.appending(path: UUID().uuidString + "-" + url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        }
    }

    private final class ProgressLog: Sendable {
        let values = Mutex<[FileOperationProgress]>([])

        func add(_ progress: FileOperationProgress) {
            values.withLock { $0.append(progress) }
        }

        var all: [FileOperationProgress] {
            values.withLock { $0 }
        }
    }

    /// The real rules, with the test's folder in the user's temporary folder, where the files are theirs.
    private func rules(home: String = "/Users/nobody") -> SafetyRules {
        SafetyRules(home: home, volumeRoots: ["/"], appBundle: nil, temporaryFolder: NSTemporaryDirectory())
    }

    private func run(
        _ kind: FileOperation.Kind,
        _ items: [URL],
        in folder: TemporaryFolder,
        rules: SafetyRules? = nil,
        movesByCopying: Bool = false,
        cancellation: CancellationFlag = CancellationFlag(),
        log: ProgressLog = ProgressLog()
    ) async throws -> FileOperationReport {
        let trash = try folder.folder(".TestTrash")
        let fileOperator = FileOperator(rules: rules ?? self.rules(), trasher: FolderTrash(folder: trash), movesByCopying: movesByCopying)
        let bytes = items.reduce(Int64(0)) { $0 + ItemCensus.of($1).bytes }
        return await fileOperator
            .run(FileOperation(kind: kind, items: items, totalBytes: bytes), cancellation: cancellation) { log.add($0) }
    }

    @Test func copiesFilesAndFoldersWithProgressAndKeepsBothNames() async throws {
        let folder = try TemporaryFolder()
        let file = try folder.file("source/movie.mov", size: 3_000_000)
        try folder.file("source/Album/a.jpg", size: 500_000)
        let album = folder.url.appending(path: "source/Album")
        let destination = try folder.folder("destination")
        try folder.file("destination/movie.mov", size: 10)
        let log = ProgressLog()
        let report = try await run(.copy(to: destination), [file, album], in: folder, log: log)
        #expect(report.failures.isEmpty)
        #expect(report.completed == [file, album])
        #expect(report.created.map(\.lastPathComponent) == ["movie 2.mov", "Album"])
        #expect(ItemCensus.of(destination.appending(path: "movie 2.mov")) == ItemCensus(files: 1, bytes: 3_000_000))
        #expect(ItemCensus.of(destination.appending(path: "Album")) == ItemCensus(files: 1, bytes: 500_000))
        #expect(FileManager.default.fileExists(atPath: file.path), "a copy leaves the original")
        #expect(log.all.last?.completedItems == 2)
        #expect(log.all.last?.completedBytes == 3_500_000)
    }

    @Test func movesOnTheSameVolumeRename() async throws {
        let folder = try TemporaryFolder()
        let file = try folder.file("a/big.bin", size: 2_000_000)
        let destination = try folder.folder("b")
        let report = try await run(.move(to: destination), [file], in: folder)
        #expect(report.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "big.bin").path))
    }

    @Test func movesToAnotherVolumeCopyCheckThenRemove() async throws {
        let folder = try TemporaryFolder()
        try folder.file("a/Project/one.bin", size: 1_000_000)
        try folder.file("a/Project/two/three.bin", size: 2_000_000)
        let project = folder.url.appending(path: "a/Project")
        let destination = try folder.folder("b")
        let report = try await run(.move(to: destination), [project], in: folder, movesByCopying: true)
        #expect(report.failures.isEmpty)
        #expect(report.completed == [project])
        #expect(!FileManager.default.fileExists(atPath: project.path))
        #expect(ItemCensus.of(destination.appending(path: "Project")) == ItemCensus(files: 2, bytes: 3_000_000))
    }

    @Test func trashedItemsComeBackWithUndo() async throws {
        let folder = try TemporaryFolder()
        let file = try folder.file("data/old.zip", size: 1_200_000)
        let report = try await run(.trash, [file], in: folder)
        #expect(report.trashed.count == 1)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let failures = await FileOperator(rules: rules()).restore(report.trashed)
        #expect(failures.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func undoNeverReplacesWhatIsThereNow() async throws {
        let folder = try TemporaryFolder()
        let file = try folder.file("data/old.zip", size: 1000)
        let report = try await run(.trash, [file], in: folder)
        try folder.file("data/old.zip", size: 10)
        let failures = await FileOperator(rules: rules()).restore(report.trashed)
        #expect(failures.count == 1)
        #expect(ItemCensus.of(file).bytes == 10)
    }

    @Test func deletingASymbolicLinkLeavesItsTarget() async throws {
        let folder = try TemporaryFolder()
        let target = try folder.file("keep/important.db", size: 5000)
        let link = folder.url.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let report = try await run(.delete, [link], in: folder)
        #expect(report.completed == [link])
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == nil)
    }

    @Test func protectedItemsAreRefusedAndLeftAlone() async throws {
        let folder = try TemporaryFolder()
        let documents = try folder.folder("Documents")
        let loose = try folder.file("big.iso", size: 100)
        let report = try await run(.trash, [documents, loose], in: folder, rules: rules(home: folder.path))
        #expect(report.refused.map(\.url) == [documents])
        #expect(report.completed == [loose])
        #expect(FileManager.default.fileExists(atPath: documents.path))
    }

    @Test func aFolderCannotBeCopiedOrMovedIntoItself() async throws {
        let folder = try TemporaryFolder()
        let project = try folder.folder("Project")
        let inner = try folder.folder("Project/inner")
        let report = try await run(.copy(to: inner), [project], in: folder)
        #expect(report.refused.count == 1)
        #expect(report.completed.isEmpty)
    }

    @Test func oneFailureDoesNotStopTheOthers() async throws {
        let folder = try TemporaryFolder()
        let good = try folder.file("good.bin", size: 100)
        let missing = folder.url.appending(path: "gone.bin")
        let destination = try folder.folder("copies")
        let report = try await run(.copy(to: destination), [missing, good], in: folder)
        #expect(report.refused.count == 1, "an item that is not there is refused before anything runs")
        #expect(report.completed == [good])
    }

    @Test func aCopyIntoAFolderThatCannotBeWrittenFailsCleanly() async throws {
        let folder = try TemporaryFolder()
        let file = try folder.file("file.bin", size: 100)
        let locked = try folder.folder("locked")
        #expect(chmod(locked.path, 0o555) == 0)
        defer { chmod(locked.path, 0o755) }
        let report = try await run(.copy(to: locked), [file], in: folder)
        #expect(report.failures.count == 1)
        #expect(report.failures.first?.message.isEmpty == false)
        #expect(try FileManager.default.contentsOfDirectory(atPath: locked.path).isEmpty)
    }

    @Test func aCancelledOperationStopsBeforeTheNextItem() async throws {
        let folder = try TemporaryFolder()
        let first = try folder.file("one.bin", size: 100)
        let second = try folder.file("two.bin", size: 100)
        let flag = CancellationFlag()
        flag.cancel()
        let report = try await run(.delete, [first, second], in: folder, cancellation: flag)
        #expect(report.wasCancelled)
        #expect(report.completed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    @Test(arguments: [
        ("Report.pdf", false, ["Report.pdf"], "Report 2.pdf"),
        ("Report.pdf", false, ["Report.pdf", "Report 2.pdf"], "Report 3.pdf"),
        ("Photos", true, ["Photos"], "Photos 2"),
        ("archive.tar.gz", false, ["archive.tar.gz"], "archive.tar 2.gz"),
        (".zshrc", false, [".zshrc"], ".zshrc 2"),
        ("free.txt", false, [], "free.txt"),
    ])
    func namesAreKeptFreeTheWayFinderDoes(_ name: String, _ isFolder: Bool, _ taken: [String], _ expected: String) {
        #expect(UniqueName.name(for: name, isFolder: isFolder) { taken.contains($0) } == expected)
    }

    @Test func errorsReadAsSentences() {
        #expect(FileErrorMessage.message(for: ENOSPC) == "There is not enough free space there.")
        #expect(FileErrorMessage.message(for: EPERM).contains("Full Disk Access"))
        #expect(FileErrorMessage.message(for: EIO).hasSuffix("."))
        #expect(FileErrorMessage.message(for: EDEADLK).contains("cloud"))
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 4,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))]
        )
        #expect(FileErrorMessage.message(for: error) == "It is no longer there.")
    }
}
