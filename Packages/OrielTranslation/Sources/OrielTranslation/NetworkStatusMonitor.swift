import Network

/// Reports whether the Mac has a network path, for the offline indicator (PLAN §7.7.7). It runs only while a
/// translation is open, and `NWPathMonitor` delivers changes as they happen; nothing is polled.
@MainActor
final class NetworkStatusMonitor {
    private var task: Task<Void, Never>?

    /// Calls `onChange` with the current state at once, then on every change, until `stop()`.
    func start(onChange: @escaping @MainActor (_ isOffline: Bool) -> Void) {
        stop()
        task = Task {
            for await path in NWPathMonitor() {
                onChange(path.status != .satisfied)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
