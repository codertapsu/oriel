import Foundation

/// A clock the test moves by hand: sleepers wake only when `advance(by:)` passes their deadline.
@MainActor
final class ManualClock {
    private(set) var now = ContinuousClock.now
    private var sleepers: [(deadline: ContinuousClock.Instant, continuation: CheckedContinuation<Void, any Error>)] = []

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        guard deadline > now else { return }
        try await withCheckedThrowingContinuation { continuation in
            sleepers.append((deadline, continuation))
        }
    }

    /// Moves time on, wakes the sleepers that are due, and lets the main actor run what they started.
    func advance(by duration: Duration) async {
        now += duration
        let due = sleepers.filter { $0.deadline <= now }
        sleepers.removeAll { $0.deadline <= now }
        for sleeper in due {
            sleeper.continuation.resume()
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    /// Ends every sleep, for the end of a test.
    func cancelAll() {
        for sleeper in sleepers {
            sleeper.continuation.resume(throwing: CancellationError())
        }
        sleepers = []
    }
}
