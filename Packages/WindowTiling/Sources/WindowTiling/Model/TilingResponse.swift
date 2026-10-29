/// What the user gets after an action. A move speaks for itself (VoiceOver hears the action's name); a key that did
/// nothing beeps, as macOS does; a window skipped on purpose gets a short toast that says why. Pure.
nonisolated enum TilingResponse: Sendable, Equatable {
    /// For VoiceOver only.
    case announcement(String)
    case beep
    case toast(String, symbol: String)

    static func to(_ outcome: TilingOutcome, of action: TilingAction, appName: String?) -> TilingResponse {
        switch outcome {
        case .moved:
            .announcement(action.title)
        case .unchanged, .noWindow:
            .beep
        case .skipped(.fullScreen):
            .toast("Full-screen windows can't be tiled", symbol: "arrow.up.left.and.arrow.down.right")
        case .skipped(.sheet):
            .toast("Close the sheet to tile its window", symbol: "macwindow")
        case .skipped(.notMovable):
            .toast("This window can't be moved or resized", symbol: "macwindow")
        case .appDidNotRespond:
            .toast("\(appName ?? "The app") didn't respond", symbol: "hourglass")
        }
    }
}
