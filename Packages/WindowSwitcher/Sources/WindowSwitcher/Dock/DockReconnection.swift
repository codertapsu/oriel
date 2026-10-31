import ApplicationServices

/// When the Dock's AX actor observes the Dock again within the same process (PLAN §7.1.12), as a pure value. The Dock
/// can replace its list without restarting, which no pid change reports; a read of the old list then fails with
/// `kAXErrorInvalidUIElement`, and only that has the Dock observed again. It happens once until a list answers, so a Dock
/// that keeps failing is not observed again and again: it waits for the controller to start the reader anew (another
/// process, or one that has finished launching).
nonisolated struct DockReconnection: Sendable, Equatable {
    /// Whether the Dock was observed again since a list last answered.
    private(set) var hasReconnected = false

    /// Whether a read of the list that gave `error` observes the Dock again. A list that answers, with a value or with
    /// none, lets the next replacement be followed; a slow Dock, or Accessibility turned off, is no reason.
    mutating func reconnects(after error: AXError) -> Bool {
        switch error {
        case .success, .noValue:
            hasReconnected = false
            return false
        case .invalidUIElement:
            guard !hasReconnected else { return false }
            hasReconnected = true
            return true
        default:
            return false
        }
    }
}
