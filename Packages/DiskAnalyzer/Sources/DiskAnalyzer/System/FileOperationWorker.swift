import Darwin
import Foundation

/// Does one confirmed operation, item by item, on a thread of its own: file work blocks, so it stays off Swift's
/// cooperative pool. Every item gets its own outcome; one that fails does not stop the others, and Cancel stops before
/// the next item or in the middle of a copy.
///
/// Unchecked `Sendable`: the operator makes it and hands it to the operation's thread, the only one that uses it.
final nonisolated class FileOperationWorker: @unchecked Sendable {
    private let operation: FileOperation
    private let trasher: any Trashing
    /// Moves copy, check and remove even on one volume: how tests reach the path a move to another volume takes.
    private let movesByCopying: Bool
    private let cancellation: CancellationFlag
    private let progress: @Sendable (FileOperationProgress) -> Void
    private let clock = ContinuousClock()
    private var lastReport: ContinuousClock.Instant
    private var state = FileOperationProgress()
    private var report = FileOperationReport()
    /// Content bytes of the items finished, for the progress of the next.
    private var finishedBytes: Int64 = 0

    init(
        operation: FileOperation,
        trasher: any Trashing,
        movesByCopying: Bool = false,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) {
        self.operation = operation
        self.trasher = trasher
        self.movesByCopying = movesByCopying
        self.cancellation = cancellation
        self.progress = progress
        lastReport = clock.now
        state.totalItems = operation.items.count
        state.totalBytes = operation.kind.isDestructive ? 0 : operation.totalBytes
    }

    func perform() -> FileOperationReport {
        ScanIOPolicy.applyToCurrentThread()
        for item in operation.items {
            guard !cancellation.isCancelled else {
                report.wasCancelled = true
                break
            }
            state.currentName = item.lastPathComponent
            send(force: true)
            switch operation.kind {
            case let .copy(folder): copy(item, into: folder)
            case let .move(folder): move(item, into: folder)
            case .trash: trash(item)
            case .delete: delete(item)
            }
            state.completedItems += 1
            send(force: true)
        }
        report.wasCancelled = report.wasCancelled || cancellation.isCancelled
        return report
    }

    // MARK: Operations

    private func copy(_ item: URL, into folder: URL) {
        let destination = destination(for: item, in: folder)
        do throws(FileCopier.Failure) {
            try copyData(item, to: destination)
            report.completed.append(item)
            report.created.append(destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            fail(item, FileErrorMessage.message(for: error.code))
        }
    }

    private func move(_ item: URL, into folder: URL) {
        if item.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL {
            report.completed.append(item)
            report.created.append(item)
            return
        }
        let destination = destination(for: item, in: folder)
        // On the same volume a move is a rename: instant, and it never replaces what is there.
        if !movesByCopying, renamex_np(item.path, destination.path, UInt32(RENAME_EXCL)) == 0 {
            finishedBytes += ItemCensus.of(destination).bytes
            report.completed.append(item)
            report.created.append(destination)
            return
        }
        let code = movesByCopying ? EXDEV : errno
        guard code == EXDEV else {
            fail(item, FileErrorMessage.message(for: code))
            return
        }
        moveAcrossVolumes(item, to: destination)
    }

    /// Copies, checks that the copy has every file and byte, and only then removes the original.
    private func moveAcrossVolumes(_ item: URL, to destination: URL) {
        let before = ItemCensus.of(item)
        do throws(FileCopier.Failure) {
            try copyData(item, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            fail(item, FileErrorMessage.message(for: error.code))
            return
        }
        guard ItemCensus.of(destination) == before else {
            try? FileManager.default.removeItem(at: destination)
            fail(item, "The copy did not match the original, so the original was kept.")
            return
        }
        report.created.append(destination)
        do {
            try FileManager.default.removeItem(at: item)
            report.completed.append(item)
        } catch {
            fail(item, "Copied, but the original could not be removed: " + FileErrorMessage.message(for: error))
        }
    }

    private func trash(_ item: URL) {
        do {
            if let inTrash = try trasher.trash(item) {
                report.trashed.append(TrashedItem(original: item, inTrash: inTrash))
            }
            report.completed.append(item)
        } catch {
            fail(item, FileErrorMessage.message(for: error))
        }
    }

    private func delete(_ item: URL) {
        do {
            // Removes a symbolic link itself, never what it points to.
            try FileManager.default.removeItem(at: item)
            report.completed.append(item)
        } catch {
            fail(item, FileErrorMessage.message(for: error))
        }
    }

    // MARK: Helpers

    private func copyData(_ item: URL, to destination: URL) throws(FileCopier.Failure) {
        let base = finishedBytes
        let copier = FileCopier(cancellation: cancellation) { [self] copied in
            state.completedBytes = base + copied
            send(force: false)
        }
        try copier.copy(item.path, to: destination.path)
        finishedBytes = base + copier.copiedBytes
        state.completedBytes = finishedBytes
    }

    private func destination(for item: URL, in folder: URL) -> URL {
        var info = stat()
        let isFolder = lstat(item.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
        let name = UniqueName.name(for: item.lastPathComponent, isFolder: isFolder) { candidate in
            var existing = stat()
            return lstat(folder.appending(path: candidate).path, &existing) == 0
        }
        return folder.appending(path: name, directoryHint: isFolder ? .isDirectory : .notDirectory)
    }

    private func fail(_ item: URL, _ message: String) {
        report.failures.append(FileOperationReport.Failure(url: item, message: message))
    }

    /// Reports progress at most ten times a second, unless `force`.
    private func send(force: Bool) {
        let now = clock.now
        guard force || now - lastReport >= .milliseconds(100) else { return }
        lastReport = now
        progress(state)
    }
}
