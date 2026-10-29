import Darwin
import Foundation
import OrielCore

/// Reads one complete sample off the main thread and turns it into a snapshot, keeping what the next one needs: each
/// process's baseline, the graphs' history, heavy-use tracking and the network totals.
///
/// The user's own processes are read with libproc, which is exact and costs about a microsecond each. Other users'
/// processes need `/bin/ps` (setuid root) and per-process traffic needs `/usr/bin/nettop`; each is one short-lived
/// child process, run only when the request asks for it, and both run at the same time. `ps` reads every other user's
/// process every `fullPSInterval`, and in between only the ones that were busy or are new: that cuts its cost by about
/// two thirds at the default interval, while a busy daemon such as WindowServer still updates every sample.
actor ActivitySampler {
    /// About 6 s: every third sample at the default 2-second interval, every other one at 5 s.
    static let fullPSInterval: UInt64 = 5_900_000_000

    private let myUID = geteuid()
    private let builder: SnapshotBuilder
    private var previous: RawSample?
    private var memory = SampleMemory()
    private var history: ActivityHistory
    private var detector = HeavyConsumerDetector()
    private var networkTotals: [ProcessIdentity: TrafficBytes] = [:]
    /// Paths by identity and short name: an `exec` keeps the pid and start time but changes both.
    private var paths: [ProcessIdentity: (command: String, path: String?)] = [:]
    private var userNames: [UInt32: String] = [:]
    private var coreTypes: [CoreType]?
    private var lastFullPS: UInt64?
    private let physicalMemory = SystemStats.physicalMemory

    init(historyCapacity: Int = 150) {
        builder = SnapshotBuilder(myUID: geteuid(), onAppleSilicon: HardwareInfo.isAppleSiliconHardware, coreCount: SystemStats.coreCount)
        history = ActivityHistory(capacity: historyCapacity)
    }

    func sample(_ request: SampleRequest) async -> ActivitySnapshot {
        let raw = await read(request)
        let network = memory.network(at: raw.time)
        var processes = builder.processes(current: raw, baselines: memory.baselines, network: network, apps: request.apps) {
            userName($0)
        }
        memory.carry(into: &processes, readings: raw.processes, at: raw.time)
        detector.thresholds = request.thresholds
        let flags = detector.update(processes, from: previous?.time ?? raw.time, to: raw.time)
        let networkSeconds = network.map { Double(raw.time - $0.time) / 1_000_000_000 }
        var totals: [ProcessIdentity: TrafficBytes] = [:]
        for index in processes.indices {
            let id = processes[index].id
            processes[index].heavy = flags[id] ?? []
            if let rate = processes[index].network, let seconds = networkSeconds {
                let added = TrafficBytes(
                    received: UInt64((rate.received * seconds).rounded()),
                    sent: UInt64((rate.sent * seconds).rounded())
                )
                totals[id] = (networkTotals[id] ?? .zero) + added
            } else if let total = networkTotals[id] {
                totals[id] = total
            }
            processes[index].networkTotal = raw.sources.contains(.network) ? totals[id] : nil
        }
        networkTotals = totals
        let system = builder.system(previous: previous, current: raw, processes: processes)
        history.resize(to: request.historyCapacity)
        history.record(system, processes: processes)
        memory.remember(raw, processes)
        let seconds = SnapshotBuilder.seconds(from: previous, to: raw)
        previous = raw
        return ActivitySnapshot(
            date: Date(),
            interval: seconds,
            processes: processes,
            system: system,
            history: history.snapshot,
            selectedHistory: request.selected.flatMap { history.process($0) },
            sources: raw.sources
        )
    }

    /// The history of one process, for a selection made between samples.
    func history(of identity: ProcessIdentity) -> ProcessHistorySnapshot? {
        history.process(identity)
    }

    // MARK: Reading

    private func read(_ request: SampleRequest) async -> RawSample {
        let time = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let table = ProcessTable.all()
        var readings: [ProcessReading] = []
        readings.reserveCapacity(table.count)
        var others: [ProcessIdentity] = []
        var seen: [ProcessIdentity: (command: String, path: String?)] = [:]
        seen.reserveCapacity(table.count)
        for basics in table {
            let path = path(of: basics)
            seen[basics.identity] = (basics.command, path)
            var reading = ProcessReading(basics: basics, path: path)
            if basics.uid == myUID {
                reading.counters = ProcessTable.counters(of: basics.pid, kernelState: basics.kernelState)
            } else if basics.pid > 0, !basics.isZombie {
                others.append(basics.identity)
            }
            readings.append(reading)
        }
        paths = seen
        let otherPIDs = request.sources.contains(.otherUsers) ? psTargets(others, at: time) : []
        let wantsNetwork = request.sources.contains(.network)
        async let psRecords = Self.otherUsers(otherPIDs)
        async let traffic = wantsNetwork ? Self.traffic() : nil
        let assertions = request.sources.contains(.sleepAssertions) ? PowerReader.sleepAssertions() : [:]
        let system = readSystem(devices: request.sources.contains(.devices))
        let (records, network) = await (psRecords, traffic)
        for index in readings.indices {
            let pid = readings[index].basics.pid
            if let record = records?[pid], readings[index].counters == nil {
                readings[index].counters = ProcessCounters(
                    source: .ps,
                    cpuTime: record.cpuTime,
                    residentSize: record.residentSize,
                    status: record.status
                )
            }
            readings[index].network = network?[pid]
            readings[index].sleepAssertions = assertions[pid] ?? []
        }
        var sources = request.sources.intersection([.sleepAssertions, .devices])
        // Measured, or nothing to measure this time; missing only when ps failed.
        if request.sources.contains(.otherUsers), records != nil || otherPIDs.isEmpty {
            sources.insert(.otherUsers)
        }
        if network != nil {
            sources.insert(.network)
        }
        return RawSample(time: time, processes: readings, system: system, sources: sources)
    }

    /// Every other user's process for a full run, else the busy and the new ones.
    private func psTargets(_ others: [ProcessIdentity], at time: UInt64) -> [Int32] {
        if let lastFullPS, time >= lastFullPS, time - lastFullPS < Self.fullPSInterval {
            return memory.busy(others).map(\.pid)
        }
        lastFullPS = time
        return others.map(\.pid)
    }

    private func readSystem(devices: Bool) -> SystemReading {
        var system = SystemReading()
        system.cores = SystemStats.cores()
        system.coreTypes = types(for: system.cores.count)
        if let memory = SystemStats.memory() {
            system.memory = memory.counts
            system.pageSize = memory.pageSize
        }
        system.physicalMemory = physicalMemory
        let swap = SystemStats.swap()
        system.swapUsed = swap.used
        system.swapTotal = swap.total
        system.pressure = SystemStats.pressure()
        system.loadAverage = SystemStats.loadAverage()
        system.thermal = ThermalLevel(ProcessInfo.processInfo.thermalState)
        if devices {
            system.disks = IORegistryReader.disks()
            system.interfaces = NetworkInterfaces.counters()
            system.gpus = IORegistryReader.gpus()
            system.battery = PowerReader.battery()
        }
        return system
    }

    private func path(of basics: ProcessBasics) -> String? {
        if let known = paths[basics.identity], known.command == basics.command {
            return known.path
        }
        return basics.pid == 0 ? nil : ProcessTable.path(of: basics.pid)
    }

    private func userName(_ uid: UInt32) -> String {
        if let name = userNames[uid] {
            return name
        }
        let name = UserDirectory.name(of: uid)
        userNames[uid] = name
        return name
    }

    /// The device tree's core types, read once; the performance levels when it has none.
    private func types(for count: Int) -> [CoreType] {
        if let coreTypes, coreTypes.count == count {
            return coreTypes
        }
        let types = IORegistryReader.coreTypes().flatMap { $0.count == count ? $0 : nil }
            ?? CoreType.fallback(levels: SystemStats.performanceLevels(), total: count)
        coreTypes = types
        return types
    }

    // MARK: Tools

    static let ps = URL(fileURLWithPath: "/bin/ps")
    static let nettop = URL(fileURLWithPath: "/usr/bin/nettop")

    /// Other users' CPU time, resident memory and state, from `ps -p` with their pids only: half the cost of `ps -ax`.
    private static func otherUsers(_ pids: [Int32]) async -> [Int32: PSParser.Record]? {
        guard !pids.isEmpty else { return nil }
        let list = pids.map(String.init).joined(separator: ",")
        guard let result = try? await CommandRunner.run(ps, ["-o", PSParser.columns, "-p", list], timeout: .seconds(5)) else { return nil }
        // ps exits 1 when a listed process ended in between; what it printed is still right.
        let records = PSParser.parse(result.output)
        return records.isEmpty ? nil : records
    }

    /// One run of nettop: a few milliseconds. A long-lived nettop in logging mode would spin a core between samples.
    private static func traffic() async -> [Int32: ProcessNetwork]? {
        guard let result = try? await CommandRunner.run(nettop, NettopParser.arguments, timeout: .seconds(5)), result.status == 0 else {
            return nil
        }
        return NettopParser.parse(result.text)
    }
}
