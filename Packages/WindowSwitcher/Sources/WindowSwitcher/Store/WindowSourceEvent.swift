/// A change the window source noticed (PLAN §6.5): AX observer notifications per app and NSWorkspace
/// notifications. Events only say what to re-read; the store reads it.
nonisolated enum WindowSourceEvent: Sendable, Equatable {
    case appLaunched(Int32)
    case appTerminated(Int32)
    /// Also the moment to retry an app that refused Accessibility while launching.
    case appActivated(Int32)
    case appHidden(Int32)
    case appUnhidden(Int32)
    /// A window of the app was created, destroyed, moved, resized, retitled, minimized or deminimized.
    case windowsChanged(Int32)
    /// The app's focused (or main) window changed, which feeds the MRU order.
    case focusedWindowChanged(Int32)
    case activeSpaceChanged
    case screensChanged
    /// The screen was unlocked, the displays woke, or this user's session became active again. While the
    /// screen is locked, Accessibility lists no real windows (macOS 27.0.1), so everything is re-read.
    case sessionResumed
}
