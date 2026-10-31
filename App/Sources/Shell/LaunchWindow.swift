/// The window a launch the user made opens (Settings, or onboarding until it is done; PLAN §10.1), shown a moment after
/// Oriel starts unless it is asked to do something else first. macOS may report the launch it makes to perform an App
/// Intent (from Shortcuts or Spotlight) as a default launch, and the intent arrives just after it; a window opened over
/// its work would be in the way. One-shot, not a timer.
final class LaunchWindow {
    static let delay: Duration = .milliseconds(500)

    private var task: Task<Void, Never>?

    var isPending: Bool {
        task != nil
    }

    /// Calls `open` after `delay`, unless `cancel()` comes first.
    func schedule(after delay: Duration = LaunchWindow.delay, _ open: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.task = nil
            open()
        }
    }

    /// Oriel was asked to do something: the launch's window gives way.
    func cancel() {
        task?.cancel()
        task = nil
    }
}
