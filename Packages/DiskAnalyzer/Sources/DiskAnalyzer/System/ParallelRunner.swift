import Foundation
import Synchronization

/// Runs blocking work for a range of indices on a few threads of its own, with the scanning I/O rules (no downloads
/// of cloud files, no access-time updates), and returns when all of it is done. For hashing, which reads files and
/// must not tie up Swift's cooperative pool or change the I/O policy of shared threads.
nonisolated enum ParallelRunner {
    private final class Counter: Sendable {
        let next = Atomic<Int>(0)
    }

    static func forEach(_ count: Int, threads: Int, work: @escaping @Sendable (Int) -> Void) {
        guard count > 0 else { return }
        let counter = Counter()
        let group = DispatchGroup()
        for number in 0 ..< max(1, min(threads, count)) {
            group.enter()
            let thread = Thread {
                ScanIOPolicy.applyToCurrentThread()
                while true {
                    let index = counter.next.add(1, ordering: .relaxed).oldValue
                    guard index < count else { break }
                    work(index)
                }
                group.leave()
            }
            thread.name = "Oriel disk work \(number + 1)"
            thread.qualityOfService = .userInitiated
            thread.start()
        }
        group.wait()
    }
}
