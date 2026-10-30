/// What the Dock's Accessibility notifications say (PLAN §7.1.12). They only say what to read again: the controller
/// reads it through `DockAccessibility`.
nonisolated enum DockEvent: Sendable, Equatable {
    /// The pointer moved onto another icon, or off the Dock (`AXSelectedChildrenChanged`).
    case hoverChanged
    /// An icon was added or removed: an app started or quit, a window was minimized or restored (`AXCreated`,
    /// `AXUIElementDestroyed`). The Dock animates the others into place.
    case itemsChanged
}
