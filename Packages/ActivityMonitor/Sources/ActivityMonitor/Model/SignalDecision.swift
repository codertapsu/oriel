/// How an action on a process is carried out, or why it is not.
nonisolated enum SignalDecision: Sendable, Equatable {
    /// Not done, and this says why.
    case refuse(String)
    /// `NSRunningApplication.terminate()`, or `forceTerminate()`.
    case terminateApp(force: Bool)
    /// `kill(2)` on one of the user's own processes.
    case send(ProcessSignal)
    /// Another user's process: only an administrator may signal it, through the system's password prompt.
    case needsAdministrator(ProcessSignal)
}
