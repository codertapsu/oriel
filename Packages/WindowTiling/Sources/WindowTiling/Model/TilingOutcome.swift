/// How one action went, for the feedback on the main actor: nothing when it worked, a beep when there was nothing to
/// do, a short toast when a window was skipped on purpose.
nonisolated enum TilingOutcome: Sendable, Equatable {
    /// Why a window was left alone.
    nonisolated enum SkipReason: Sendable, Equatable {
        /// Full-screen windows live in their own Space and keep their size.
        case fullScreen
        /// A sheet moves with its window.
        case sheet
        /// The app does not let Accessibility move this window.
        case notMovable
    }

    case moved
    /// Nothing to do: nothing to restore, one display only, or no larger or smaller to go.
    case unchanged
    /// The app in front has no window, or none that is focused.
    case noWindow
    case skipped(SkipReason)
    /// The app did not answer within the messaging timeout: it is busy, hung or still launching.
    case appDidNotRespond
}
