/// What the kernel's process table says about every process, whoever owns it: one `sysctl(KERN_PROC_ALL)` call
/// gives all of it at once.
nonisolated struct ProcessBasics: Sendable, Equatable {
    let pid: Int32
    let parentPID: Int32
    /// The effective user, which decides whether macOS lets this user read the process's usage.
    let uid: UInt32
    /// Microseconds since 1970.
    let startTime: UInt64
    /// The kernel's short name (`p_comm`), at most 16 characters.
    let command: String
    /// The kernel's `p_stat`.
    let kernelState: Int8
    /// Intel code running under Rosetta.
    let isTranslated: Bool

    var identity: ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: startTime)
    }

    var isZombie: Bool {
        kernelState == 5
    }
}
