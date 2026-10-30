/// A command of the tool that owns a folder, which knows what may go better than any rule (PLAN §7.10 item 19). Oriel
/// runs only these, as the user, after a confirmation, with fixed arguments; other tools' commands are offered to copy.
nonisolated enum CleanupCommand: String, Sendable, Equatable, CaseIterable {
    /// CoreSimulator removes the simulators' shared caches, which it builds again when a simulator starts. They belong to
    /// root, so Oriel could not move them to the Trash itself.
    case removeSimulatorCaches
    /// Simulators whose runtime is no longer installed, with their apps and data.
    case deleteUnavailableSimulators

    var executable: String {
        Simulators.xcrun
    }

    var arguments: [String] {
        switch self {
        case .removeSimulatorCaches: ["simctl", "runtime", "dyld_shared_cache", "remove", "--all"]
        case .deleteUnavailableSimulators: ["simctl", "delete", "unavailable"]
        }
    }

    /// As typed in Terminal.
    var commandLine: String {
        (["xcrun"] + arguments).joined(separator: " ")
    }

    /// What it did, for the message afterwards.
    var done: String {
        switch self {
        case .removeSimulatorCaches: "CoreSimulator removed the simulators' shared caches. It builds them again when a simulator starts."
        case .deleteUnavailableSimulators: "Simulators for runtimes that are no longer installed are gone."
        }
    }
}
