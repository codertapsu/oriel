/// Everything one sample read about one process.
nonisolated struct ProcessReading: Sendable, Equatable {
    var basics: ProcessBasics
    /// The executable, from `proc_pidpath`, which works for every user's processes except the kernel's.
    var path: String?
    /// Nil when nothing could be read: another user's process in a sample without `ps`, or one that just ended.
    var counters: ProcessCounters?
    /// Nil when nettop did not run, or listed no traffic for it.
    var network: ProcessNetwork?
    /// The kinds of power assertions it holds that keep the Mac or its display awake.
    var sleepAssertions: [String]

    init(
        basics: ProcessBasics,
        path: String? = nil,
        counters: ProcessCounters? = nil,
        network: ProcessNetwork? = nil,
        sleepAssertions: [String] = []
    ) {
        self.basics = basics
        self.path = path
        self.counters = counters
        self.network = network
        self.sleepAssertions = sleepAssertions
    }
}
