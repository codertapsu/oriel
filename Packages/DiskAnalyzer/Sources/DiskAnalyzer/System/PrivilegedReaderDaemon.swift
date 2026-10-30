import Foundation

/// The privileged helper's process (`PrivilegedReader`): Oriel's own executable, started by launchd as root for the
/// helper's Mach service. It listens for Oriel, and nothing else of Oriel starts.
public nonisolated enum PrivilegedReaderDaemon {
    /// Runs the helper when launchd started this process for it, and never returns then; nil otherwise, so Oriel starts
    /// as usual.
    @discardableResult
    public static func runIfRequested() -> Never? {
        guard let label = PrivilegedReader.label,
              isHelper(environment: ProcessInfo.processInfo.environment, userID: getuid(), parentID: getppid(), label: label)
        else { return nil }
        guard let requirement = CodeIdentity.ownRequirement() else { exit(EX_CONFIG) }
        let delegate = PrivilegedReaderListener(requirement: requirement) { exit(0) }
        let listener = NSXPCListener(machServiceName: label)
        listener.delegate = delegate
        listener.resume()
        withExtendedLifetime((listener, delegate)) { dispatchMain() }
    }

    /// The helper runs as root, and launchd puts the job's label in its `XPC_SERVICE_NAME`. Root started by launchd itself
    /// counts too: Oriel's executable has no other reason to be, and starting the app there would leave Oriel's requests
    /// unanswered. The password route's root process is started by `osascript`, not launchd.
    static func isHelper(environment: [String: String], userID: uid_t, parentID: pid_t, label: String) -> Bool {
        userID == 0 && (environment["XPC_SERVICE_NAME"] == label || parentID == 1)
    }
}
