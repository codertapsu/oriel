/// A process's counters when they were last read, and when: what its next reading is compared with. A process need not
/// be read in every sample (another user's idle process between full `ps` runs), so its rates span the time since it
/// last was.
nonisolated struct Baseline: Sendable, Equatable {
    let time: UInt64
    let counters: ProcessCounters
}
