/// Turns two samples into what the list and the summary show: percentages and rates come from what each counter added
/// in between, so the first sample shows only what is not a rate.
///
/// A process is compared only with itself (same pid and start time) and only when both samples read it the same way,
/// because `ps` and `proc_pid_rusage` count CPU time at different precisions. A counter that went down means a reset,
/// and gives no rate that time rather than a negative or huge one.
nonisolated struct SnapshotBuilder {
    let myUID: UInt32
    let onAppleSilicon: Bool
    /// CPU percentages are capped at this many cores' worth.
    let coreCount: Int

    static func seconds(from earlier: RawSample?, to now: RawSample) -> Double? {
        guard let earlier, now.time > earlier.time else { return nil }
        return Double(now.time - earlier.time) / 1_000_000_000
    }

    /// The last path component, without splitting the whole path.
    static func fileName(_ path: String) -> String? {
        guard let slash = path.lastIndex(of: "/") else { return path.isEmpty ? nil : path }
        let name = path[path.index(after: slash)...]
        return name.isEmpty ? nil : String(name)
    }

    /// What `current` added to `earlier` per second; nil when either is missing or the counter was reset.
    static func rate(_ earlier: UInt64?, _ current: UInt64?, over seconds: Double) -> Double? {
        guard let earlier, let current, current >= earlier, seconds > 0 else { return nil }
        return Double(current - earlier) / seconds
    }

    /// Compares `current` with the sample before it: what the tests and a two-sample snapshot use.
    func processes(
        previous: RawSample?,
        current: RawSample,
        apps: [Int32: AppInfo],
        userName: (UInt32) -> String
    ) -> [ProcessMetrics] {
        var baselines: [ProcessIdentity: Baseline] = [:]
        for reading in previous?.processes ?? [] {
            if let counters = reading.counters, let time = previous?.time {
                baselines[reading.basics.identity] = Baseline(time: time, counters: counters)
            }
        }
        let network = previous.flatMap { $0.sources.contains(.network) ? NetworkBaseline($0) : nil }
        return processes(current: current, baselines: baselines, network: network, apps: apps, userName: userName)
    }

    /// Compares each process with its own baseline, the last time it was read, if that is at most
    /// `SampleMemory.maxAge` ago; traffic is compared with the last nettop run.
    func processes(
        current: RawSample,
        baselines: [ProcessIdentity: Baseline],
        network: NetworkBaseline?,
        apps: [Int32: AppInfo],
        userName: (UInt32) -> String
    ) -> [ProcessMetrics] {
        let networkSeconds = current.sources.contains(.network) ? network.flatMap { seconds(from: $0.time, to: current.time) } : nil
        return current.processes.map { reading in
            let id = reading.basics.identity
            var metrics = base(reading, app: apps[reading.basics.pid], user: userName(reading.basics.uid))
            if let baseline = baselines[id], let seconds = seconds(from: baseline.time, to: current.time) {
                addRates(to: &metrics, reading: reading, earlier: baseline.counters, seconds: seconds)
            }
            if let networkSeconds, let network {
                let added = reading.network?.added(since: network.processes[id]) ?? .zero
                metrics.network = TrafficRate(added, over: networkSeconds)
            }
            return metrics
        }
    }

    /// Seconds from `earlier` to `now`, when that is a span rates can use.
    private func seconds(from earlier: UInt64, to now: UInt64) -> Double? {
        guard now > earlier, now - earlier <= SampleMemory.maxAge else { return nil }
        return Double(now - earlier) / 1_000_000_000
    }

    func system(previous: RawSample?, current: RawSample, processes: [ProcessMetrics]) -> SystemMetrics {
        let now = current.system
        var metrics = SystemMetrics(
            memory: now.memory.map {
                MemoryBreakdown(
                    counts: $0,
                    pageSize: now.pageSize,
                    physical: now.physicalMemory,
                    swapUsed: now.swapUsed,
                    swapTotal: now.swapTotal
                )
            },
            pressure: now.pressure,
            gpus: now.gpus,
            battery: now.battery,
            thermal: now.thermal,
            loadAverage: now.loadAverage,
            processCount: current.processes.count
        )
        let mine = processes.filter(\.isMine)
        metrics.ownThreadCount = mine.compactMap(\.threads).reduce(0, +)
        let powers = mine.compactMap(\.power)
        metrics.ownPower = powers.isEmpty ? nil : powers.reduce(0, +)
        guard let previous, let seconds = Self.seconds(from: previous, to: current) else { return metrics }
        let before = previous.system
        metrics.cpu = CPUTicks.load(since: before.cores, now: now.cores)
        if before.cores.count == now.cores.count {
            metrics.cores = zip(before.cores, now.cores).enumerated().compactMap { index, pair in
                pair.1.load(since: pair.0).map { CoreLoad(
                    type: now.coreTypes.indices.contains(index) ? now.coreTypes[index] : .standard,
                    load: $0
                ) }
            }
        }
        if previous.sources.contains(.devices), current.sources.contains(.devices) {
            metrics.disk = disk(before: before, now: now, seconds: seconds)
            metrics.network = network(before: before, now: now, seconds: seconds)
        }
        return metrics
    }

    // MARK: Processes

    private func base(_ reading: ProcessReading, app: AppInfo?, user: String) -> ProcessMetrics {
        let basics = reading.basics
        let counters = reading.counters
        let fileName = reading.path.flatMap(Self.fileName)
        return ProcessMetrics(
            id: basics.identity,
            parentPID: basics.parentPID,
            uid: basics.uid,
            user: user,
            name: app?.name ?? fileName ?? basics.command,
            command: basics.command,
            path: reading.path,
            app: app,
            kind: ProcessKind(isTranslated: basics.isTranslated, onAppleSilicon: onAppleSilicon),
            status: basics.isZombie ? .zombie : counters?.status,
            isMine: basics.uid == myUID,
            cpuTime: counters?.cpuTime,
            threads: counters?.threads,
            memory: counters?.footprint,
            realMemory: counters?.residentSize,
            diskRead: counters?.diskRead,
            diskWritten: counters?.diskWritten,
            sleepAssertions: reading.sleepAssertions
        )
    }

    private func addRates(to metrics: inout ProcessMetrics, reading: ProcessReading, earlier before: ProcessCounters, seconds: Double) {
        guard let now = reading.counters, now.source == before.source else { return }
        let cap = Double(max(1, coreCount)) * 100
        metrics.cpuPercent = Self.rate(before.cpuTime, now.cpuTime, over: seconds).map { min(cap, $0 / 10_000_000) }
        metrics.power = Self.rate(before.energy, now.energy, over: seconds).map { $0 / 1_000_000_000 }
        metrics.idleWakeupsPerSecond = Self.rate(before.idleWakeups, now.idleWakeups, over: seconds)
        metrics.diskReadPerSecond = Self.rate(before.diskRead, now.diskRead, over: seconds)
        metrics.diskWrittenPerSecond = Self.rate(before.diskWritten, now.diskWritten, over: seconds)
    }

    // MARK: Devices

    private func disk(before: SystemReading, now: SystemReading, seconds: Double) -> DiskActivity {
        let totals = now.disks.values.reduce(DiskCounters(), +)
        let added = now.disks.reduce(DiskCounters()) { sum, entry in
            before.disks[entry.key].map { sum + entry.value.added(since: $0) } ?? sum
        }
        return DiskActivity(
            totals: totals,
            readBytesPerSecond: Double(added.bytesRead) / seconds,
            writtenBytesPerSecond: Double(added.bytesWritten) / seconds,
            readsPerSecond: Double(added.reads) / seconds,
            writesPerSecond: Double(added.writes) / seconds
        )
    }

    private func network(before: SystemReading, now: SystemReading, seconds: Double) -> NetworkActivity {
        let totals = InterfaceCounters.totals(now.interfaces)
        let added = InterfaceCounters.added(since: before.interfaces, now: now.interfaces)
        return NetworkActivity(
            bytes: totals.bytes,
            packets: totals.packets,
            bytesPerSecond: TrafficRate(added.bytes, over: seconds),
            packetsPerSecond: TrafficRate(added.packets, over: seconds)
        )
    }
}
