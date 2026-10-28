/// The answer to "which windows does this app list?".
nonisolated enum AXWindowsResult: Sendable, Equatable {
    case windows([AXWindowRecord])
    /// The app did not answer: still launching, hung, or it does not implement Accessibility. Retried when it
    /// is activated, never on a timer (PLAN §7.1.1).
    case refused
}
