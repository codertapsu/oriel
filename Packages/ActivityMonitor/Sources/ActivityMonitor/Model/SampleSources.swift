/// The readers a sample used beyond the cheap ones that always run: each costs a process launch or an IPC round trip,
/// so a sample asks only for what the window shows.
nonisolated struct SampleSources: OptionSet, Sendable, Hashable {
    let rawValue: Int

    /// `/bin/ps` for other users' CPU time and resident memory.
    static let otherUsers = SampleSources(rawValue: 1 << 0)
    /// `/usr/bin/nettop` for each process's traffic.
    static let network = SampleSources(rawValue: 1 << 1)
    /// `IOPMCopyAssertionsByProcess` for the processes keeping the Mac awake.
    static let sleepAssertions = SampleSources(rawValue: 1 << 2)
    /// The disks, network interfaces, GPU and battery, for the summary.
    static let devices = SampleSources(rawValue: 1 << 3)

    static let all: SampleSources = [.otherUsers, .network, .sleepAssertions, .devices]
}
