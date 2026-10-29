/// What the user asked to do to a process.
nonisolated enum ProcessAction: Sendable, Equatable {
    /// Ask it to quit: an app can save its documents first.
    case quit
    /// End it at once.
    case forceQuit
    case signal(ProcessSignal)

    /// The signal a process that is not an app gets.
    var signal: ProcessSignal {
        switch self {
        case .quit: .terminate
        case .forceQuit: .kill
        case let .signal(signal): signal
        }
    }
}
