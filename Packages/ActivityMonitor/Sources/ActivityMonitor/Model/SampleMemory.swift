/// What the sampler keeps from one sample to the next: each process's last counters (its baseline), the last nettop
/// run, and the numbers last shown for each process, which a sample that did not read it shows again.
///
/// Values are kept for at most `maxAge`: an older baseline gives no rate (the window was covered, or the tab did not
/// need `ps`), and an older number is not shown again.
nonisolated struct SampleMemory: Sendable {
    /// 15 s in nanoseconds: three samples at the longest interval.
    static let maxAge: UInt64 = 15_000_000_000

    private(set) var baselines: [ProcessIdentity: Baseline] = [:]
    private(set) var network: NetworkBaseline?
    /// The numbers last measured for each process, with the time of that measurement.
    private var measured: [ProcessIdentity: (time: UInt64, metrics: ProcessMetrics)] = [:]

    /// The last nettop run, if recent enough.
    func network(at time: UInt64) -> NetworkBaseline? {
        network.flatMap { time >= $0.time && time - $0.time <= Self.maxAge ? $0 : nil }
    }

    /// For each process this sample did not read, the numbers it was last measured with, if recent.
    func carry(into processes: inout [ProcessMetrics], readings: [ProcessReading], at time: UInt64) {
        for index in processes.indices where index < readings.count && readings[index].counters == nil {
            guard let last = measured[processes[index].id], time >= last.time, time - last.time <= Self.maxAge else { continue }
            let old = last.metrics
            processes[index].cpuPercent = old.cpuPercent
            processes[index].cpuTime = old.cpuTime
            processes[index].threads = old.threads
            processes[index].memory = old.memory
            processes[index].realMemory = old.realMemory
            processes[index].status = processes[index].status ?? old.status
            processes[index].idleWakeupsPerSecond = old.idleWakeupsPerSecond
            processes[index].power = old.power
            processes[index].diskRead = old.diskRead
            processes[index].diskWritten = old.diskWritten
            processes[index].diskReadPerSecond = old.diskReadPerSecond
            processes[index].diskWrittenPerSecond = old.diskWrittenPerSecond
        }
    }

    /// Keeps `sample`'s readings as the new baselines, and forgets processes that ended.
    mutating func remember(_ sample: RawSample, _ processes: [ProcessMetrics]) {
        var nextBaselines: [ProcessIdentity: Baseline] = [:]
        var nextMeasured: [ProcessIdentity: (time: UInt64, metrics: ProcessMetrics)] = [:]
        nextBaselines.reserveCapacity(sample.processes.count)
        nextMeasured.reserveCapacity(sample.processes.count)
        for (reading, metrics) in zip(sample.processes, processes) {
            let id = reading.basics.identity
            if let counters = reading.counters {
                nextBaselines[id] = Baseline(time: sample.time, counters: counters)
                nextMeasured[id] = (sample.time, metrics)
            } else {
                nextBaselines[id] = baselines[id]
                nextMeasured[id] = measured[id]
            }
        }
        baselines = nextBaselines
        measured = nextMeasured
        if sample.sources.contains(.network) {
            network = NetworkBaseline(sample)
        }
    }

    /// Of `identities` (other users' processes), those worth reading between full `ps` runs: the ones that used the
    /// processor when last measured, and the ones never measured.
    func busy(_ identities: [ProcessIdentity]) -> [ProcessIdentity] {
        identities.filter { id in
            guard let last = measured[id] else { return true }
            return (last.metrics.cpuPercent ?? 1) >= 0.05
        }
    }

    mutating func reset() {
        self = SampleMemory()
    }
}
