/// The answer to "which window has the focus in this app".
nonisolated enum WindowLookup<Window> {
    case found(Window)
    /// The app has no focused or main window: only the desktop, a menu or nothing at all.
    case noWindow
    /// The app did not answer within the messaging timeout, or refused (still launching, or no Accessibility).
    case refused
}
