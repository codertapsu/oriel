import Foundation

/// Waits (polling the main actor briefly) until `condition` holds, failing after a few seconds.
@MainActor
func waitUntil(timeout: Duration = .seconds(10), _ condition: @MainActor () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else {
            throw TestFailure("timed out")
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
