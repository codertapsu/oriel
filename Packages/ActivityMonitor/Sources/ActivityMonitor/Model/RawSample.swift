/// One sample: what every reader returned at one instant, before anything is compared with the sample before it.
nonisolated struct RawSample: Sendable, Equatable {
    /// Nanoseconds of uptime, which stops while the Mac sleeps, as CPU time does.
    let time: UInt64
    var processes: [ProcessReading]
    var system: SystemReading
    var sources: SampleSources

    init(time: UInt64, processes: [ProcessReading], system: SystemReading = SystemReading(), sources: SampleSources = []) {
        self.time = time
        self.processes = processes
        self.system = system
        self.sources = sources
    }
}
