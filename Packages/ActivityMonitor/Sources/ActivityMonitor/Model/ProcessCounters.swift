/// A process's cumulative counters at one instant. Rates come from two of these.
///
/// macOS gives the user's own processes everything (`proc_pid_rusage`, `PROC_PIDTASKINFO`); for other users' processes
/// only the setuid `/bin/ps` can read CPU time and resident memory, to the hundredth of a second.
nonisolated struct ProcessCounters: Sendable, Equatable {
    /// Where the CPU time came from. Times from different sources are never subtracted: `ps` rounds to 10 ms.
    enum Source: Sendable, Equatable {
        case usage
        case ps
    }

    var source: Source
    /// User plus system time, in nanoseconds.
    var cpuTime: UInt64?
    /// Activity Monitor's "Memory": the physical footprint, compressed memory included.
    var footprint: UInt64?
    /// Activity Monitor's "Real Memory": the resident set.
    var residentSize: UInt64?
    var diskRead: UInt64?
    var diskWritten: UInt64?
    /// Nanojoules, measured on Apple silicon.
    var energy: UInt64?
    var idleWakeups: UInt64?
    var threads: Int?
    var status: ProcessStatus?

    init(
        source: Source,
        cpuTime: UInt64? = nil,
        footprint: UInt64? = nil,
        residentSize: UInt64? = nil,
        diskRead: UInt64? = nil,
        diskWritten: UInt64? = nil,
        energy: UInt64? = nil,
        idleWakeups: UInt64? = nil,
        threads: Int? = nil,
        status: ProcessStatus? = nil
    ) {
        self.source = source
        self.cpuTime = cpuTime
        self.footprint = footprint
        self.residentSize = residentSize
        self.diskRead = diskRead
        self.diskWritten = diskWritten
        self.energy = energy
        self.idleWakeups = idleWakeups
        self.threads = threads
        self.status = status
    }
}
