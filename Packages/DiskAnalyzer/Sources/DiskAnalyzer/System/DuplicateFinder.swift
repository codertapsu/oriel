import Foundation
import Synchronization

/// Finds files with the same content among the files a scan kept: same size, then the same first and last 64 KB,
/// then the same SHA-256 of everything, each stage reading only what the one before left. Files only in the cloud
/// are never read (that would download them), nor further links of one file.
nonisolated enum DuplicateFinder {
    struct Progress: Sendable, Equatable {
        enum Stage: Sendable {
            case comparingEnds, comparingContents
        }

        var stage: Stage
        var doneBytes: Int64
        var totalBytes: Int64
    }

    /// The files of `tree` below `folder` worth comparing.
    static func candidates(in tree: ScanTree, under folder: Int32, minimumSize: Int64) -> [DuplicateGrouper.Candidate] {
        let excluded: ScanNodeFlags = [.cloudOnly, .duplicateLink]
        return tree.files(under: folder).compactMap { index in
            let node = tree[index]
            guard node.flags.isDisjoint(with: excluded), node.logicalSize >= minimumSize else { return nil }
            return DuplicateGrouper.Candidate(node: index, size: node.logicalSize, allocated: node.size, path: tree.path(of: index))
        }
    }

    static func find(
        _ candidates: [DuplicateGrouper.Candidate],
        minimumSize: Int64,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (Progress) -> Void
    ) async -> [DuplicateGroup] {
        await withCheckedContinuation { continuation in
            let thread = Thread {
                continuation.resume(returning: findBlocking(
                    candidates,
                    minimumSize: minimumSize,
                    cancellation: cancellation,
                    progress: progress
                ))
            }
            thread.name = "Oriel duplicates"
            thread.qualityOfService = .userInitiated
            thread.start()
        }
    }

    private static func findBlocking(
        _ candidates: [DuplicateGrouper.Candidate],
        minimumSize: Int64,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (Progress) -> Void
    ) -> [DuplicateGroup] {
        let bySize = DuplicateGrouper.sizeGroups(candidates, minimumSize: minimumSize)
        let ends = hash(bySize.flatMap(\.self), stage: .comparingEnds, cancellation: cancellation, progress: progress, using: { file, _ in
            FileHasher.edges(of: file.path, size: file.size)
        })
        let sameEnds = DuplicateGrouper.split(bySize) { ends[$0.node] }
        let fullHash: @Sendable (DuplicateGrouper.Candidate, (Int) -> Void) -> String? = { file, onBytes in
            FileHasher.full(of: file.path, cancellation: cancellation, onBytes: onBytes)
        }
        let contents = hash(
            sameEnds.flatMap(\.self),
            stage: .comparingContents,
            cancellation: cancellation,
            progress: progress,
            using: fullHash
        )
        guard !cancellation.isCancelled else { return [] }
        let parts = DuplicateGrouper.split(sameEnds) { contents[$0.node] }.map { part in
            part.map { candidate in
                var candidate = candidate
                candidate.cloneID = CloneFacts.of(candidate.path)?.cloneID
                return candidate
            }
        }
        return DuplicateGrouper.groups(parts) { contents[$0[0].node] ?? "" }
    }

    /// Hashes `files` on a few threads; node → hash, for the files that could be read.
    private static func hash(
        _ files: [DuplicateGrouper.Candidate],
        stage: Progress.Stage,
        cancellation: CancellationFlag,
        progress: @escaping @Sendable (Progress) -> Void,
        using hasher: @escaping @Sendable (DuplicateGrouper.Candidate, (Int) -> Void) -> String?
    ) -> [Int32: String] {
        let results = Hashes()
        let meter = ProgressMeter(
            stage: stage,
            total: stage == .comparingEnds ? Int64(files.count) : files.reduce(0) { $0 + $1.size },
            report: progress
        )
        ParallelRunner.forEach(files.count, threads: 4) { index in
            guard !cancellation.isCancelled else { return }
            let file = files[index]
            let hash = hasher(file) { meter.add(Int64($0)) }
            if stage == .comparingEnds {
                meter.add(1)
            }
            if let hash {
                results.set(hash, for: file.node)
            }
        }
        return results.all
    }

    /// The hashes found so far, from several threads.
    private final class Hashes: Sendable {
        private let map = Mutex<[Int32: String]>([:])

        func set(_ hash: String, for node: Int32) {
            map.withLock { $0[node] = hash }
        }

        var all: [Int32: String] {
            map.withLock { $0 }
        }
    }

    /// Adds up progress from several threads and reports it at most ten times a second.
    private final class ProgressMeter: Sendable {
        private let stage: Progress.Stage
        private let total: Int64
        private let report: @Sendable (Progress) -> Void
        private let state = Mutex<(done: Int64, last: ContinuousClock.Instant)>((0, .now))

        init(stage: Progress.Stage, total: Int64, report: @escaping @Sendable (Progress) -> Void) {
            self.stage = stage
            self.total = total
            self.report = report
        }

        func add(_ amount: Int64) {
            let due: Int64? = state.withLock { state in
                state.done += amount
                let now = ContinuousClock.now
                guard now - state.last >= .milliseconds(100) else { return nil }
                state.last = now
                return state.done
            }
            if let due {
                report(Progress(stage: stage, doneBytes: due, totalBytes: total))
            }
        }
    }
}
