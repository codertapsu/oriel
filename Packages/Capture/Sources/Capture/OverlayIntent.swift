/// What the user asked for when confirming a selection on the overlay.
nonisolated enum OverlayIntent: Sendable, Equatable {
    /// Return, ✓, a click in window or screen mode: the after-capture action from Settings.
    case capture
    /// ⌘C: copy and close, whatever the after-capture action is.
    case copy
    /// ⌘S: save to the default folder and close.
    case save
    /// ⌥Return in scrolling capture: scroll horizontally.
    case alternate
}
