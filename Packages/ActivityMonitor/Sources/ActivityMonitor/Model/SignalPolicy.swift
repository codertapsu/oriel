/// Which processes may be quit or signalled, and how. Some never are, whoever asks: the kernel, launchd,
/// WindowServer and loginwindow (losing either logs the user out) and Oriel itself. Another user's process needs an
/// administrator; the user's own apps quit through AppKit, so they can ask to save; other processes get the signal.
nonisolated struct SignalPolicy: Sendable {
    /// Oriel's own pid.
    let ownPID: Int32
    /// The user running Oriel.
    let myUID: UInt32

    /// Short names of the processes that are never signalled, with why.
    static let protected: [String: String] = [
        "kernel_task": "kernel_task is the macOS kernel. It cannot be quit.",
        "launchd": "launchd starts and looks after every other process. Quitting it would stop the Mac.",
        "WindowServer": "WindowServer draws everything on screen. Quitting it would log you out and close every app.",
        "loginwindow": "loginwindow runs your login session. Quitting it would log you out and close every app.",
    ]

    func decide(_ action: ProcessAction, for target: SignalTarget) -> SignalDecision {
        if let refusal = refusal(for: target) {
            return .refuse(refusal)
        }
        guard target.uid == myUID else {
            return .needsAdministrator(action.signal)
        }
        switch action {
        case .quit where target.isApp: return .terminateApp(force: false)
        case .forceQuit where target.isApp: return .terminateApp(force: true)
        default: return .send(action.signal)
        }
    }

    /// Why `target` may not be signalled at all, if it may not.
    func refusal(for target: SignalTarget) -> String? {
        switch target.pid {
        case ..<0: return "That is not a process."
        case 0: return Self.protected["kernel_task"]
        case 1: return Self.protected["launchd"]
        case ownPID: return "This is Oriel. To quit it, choose Quit Oriel from its menu."
        default: break
        }
        if let reason = Self.protected[target.command] {
            return reason
        }
        if target.isZombie {
            return "“\(target.name)” has already ended. It stays listed until the process that started it collects it; "
                + "quitting that process removes it."
        }
        return nil
    }
}
