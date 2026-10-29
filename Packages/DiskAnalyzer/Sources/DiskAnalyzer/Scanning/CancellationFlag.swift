import Synchronization

/// A flag that stops long work running on its own threads — a scan, a hash, a copy — from any thread, without
/// waiting for that work to reach an `await`.
final nonisolated class CancellationFlag: Sendable {
    private let state = Atomic<Bool>(false)

    init() {}

    func cancel() {
        state.store(true, ordering: .releasing)
    }

    var isCancelled: Bool {
        state.load(ordering: .acquiring)
    }
}
