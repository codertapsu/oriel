import Darwin
import Foundation

/// Copies, moves, trashes and deletes, with byte-level progress, per-item errors and Cancel. Before anything is
/// touched every item goes through the safety rules; refused items are reported and left alone. The work itself runs
/// on a thread of its own (`FileOperationWorker`).
actor FileOperator {
    private let rules: SafetyRules
    private let trasher: any Trashing
    private let movesByCopying: Bool

    init(rules: SafetyRules, trasher: any Trashing = SystemTrash(), movesByCopying: Bool = false) {
        self.rules = rules
        self.trasher = trasher
        self.movesByCopying = movesByCopying
    }

    func run(
        _ operation: FileOperation,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (FileOperationProgress) -> Void
    ) async -> FileOperationReport {
        let (allowed, refused) = check(operation)
        var checked = operation
        checked.items = allowed
        let worker = FileOperationWorker(
            operation: checked, trasher: trasher, movesByCopying: movesByCopying, cancellation: cancellation, progress: progress
        )
        var report = await withCheckedContinuation { continuation in
            let thread = Thread { continuation.resume(returning: worker.perform()) }
            thread.name = "Oriel file operation"
            thread.qualityOfService = .userInitiated
            thread.start()
        }
        report.refused = refused
        return report
    }

    /// Puts trashed items back where they were (Undo). An item whose place is taken stays in the Trash.
    func restore(_ items: [TrashedItem]) -> [FileOperationReport.Failure] {
        var failures: [FileOperationReport.Failure] = []
        for item in items {
            var info = stat()
            if lstat(item.original.path, &info) == 0 {
                failures.append(.init(url: item.original, message: "Something else is there now, so it stays in the Trash."))
                continue
            }
            do {
                try FileManager.default.moveItem(at: item.inTrash, to: item.original)
            } catch {
                failures.append(.init(url: item.original, message: FileErrorMessage.message(for: error)))
            }
        }
        return failures
    }

    /// The items the operation may touch, and those it may not, with why.
    func check(_ operation: FileOperation) -> (allowed: [URL], refused: [FileOperationReport.Failure]) {
        var allowed: [URL] = []
        var refused: [FileOperationReport.Failure] = []
        for item in operation.items {
            if let reason = refusal(for: item, kind: operation.kind) {
                refused.append(.init(url: item, message: reason))
            } else {
                allowed.append(item)
            }
        }
        return (allowed, refused)
    }

    private func refusal(for item: URL, kind: FileOperation.Kind) -> String? {
        var info = stat()
        guard lstat(item.path, &info) == 0 else { return FileErrorMessage.message(for: ENOENT) }
        switch kind {
        case let .copy(folder), let .move(folder):
            let target = folder.standardizedFileURL.path
            let source = item.standardizedFileURL.path
            if target == source || target.hasPrefix(source + "/") {
                return "A folder cannot go inside itself."
            }
            // A copy changes nothing where the item is; only moves and removals go through the rules.
            guard case .move = kind else { return nil }
        case .trash, .delete:
            break
        }
        let type = info.st_mode & S_IFMT
        let destination = type == S_IFLNK ? try? FileManager.default.destinationOfSymbolicLink(atPath: item.path) : nil
        return rules.refusal(for: item.path, isFolder: type == S_IFDIR, symlinkDestination: destination)?.message
    }
}
