import Dispatch

/// Calls back on memory pressure (PLAN §7.1.7). A dispatch source, not a timer: it costs nothing until the
/// system reports pressure.
final class MemoryPressureMonitor {
    private var source: (any DispatchSourceMemoryPressure)?

    func start(_ handler: @escaping @MainActor () -> Void) {
        guard source == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { handler() }
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
