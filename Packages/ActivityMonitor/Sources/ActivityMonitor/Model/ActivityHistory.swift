/// The graphs' history while the window is open: ring buffers of the Mac-wide series and of every process's CPU and
/// memory. It lives in the sampler and goes when the window closes; unknown values are kept as NaN, so a graph shows
/// a gap instead of a false zero.
nonisolated struct ActivityHistory: Sendable {
    /// Processes keep at most this many samples, whatever the history length: 300 × 2 floats for 800 processes is
    /// about 2 MB.
    static let processCapacityLimit = 300

    private(set) var capacity: Int
    private var system: [HistorySeries: RingBuffer<Double>]
    private var levels: RingBuffer<MemoryPressure.Level>
    private var processes: [ProcessIdentity: ProcessHistory] = [:]

    init(capacity: Int) {
        self.capacity = max(2, capacity)
        system = Dictionary(uniqueKeysWithValues: HistorySeries.allCases.map { ($0, RingBuffer(capacity: max(2, capacity))) })
        levels = RingBuffer(capacity: max(2, capacity))
    }

    var processCapacity: Int {
        min(capacity, Self.processCapacityLimit)
    }

    var sampleCount: Int {
        levels.count
    }

    mutating func record(_ metrics: SystemMetrics, processes current: [ProcessMetrics]) {
        let values: [HistorySeries: Double?] = [
            .cpuUser: metrics.cpu.map { $0.user * 100 },
            .cpuSystem: metrics.cpu.map { $0.system * 100 },
            .memoryPressure: metrics.pressure?.percent,
            .diskRead: metrics.disk?.readBytesPerSecond,
            .diskWritten: metrics.disk?.writtenBytesPerSecond,
            .networkReceived: metrics.network?.bytesPerSecond.received,
            .networkSent: metrics.network?.bytesPerSecond.sent,
            .gpu: metrics.gpus.map(\.utilization).max(),
            .power: metrics.ownPower,
        ]
        for series in HistorySeries.allCases {
            system[series, default: RingBuffer(capacity: capacity)].append((values[series] ?? nil) ?? .nan)
        }
        levels.append(metrics.pressure?.level ?? .normal)
        var next: [ProcessIdentity: ProcessHistory] = [:]
        next.reserveCapacity(current.count)
        let size = processCapacity
        for process in current {
            // Taken out of the old table, so the buffers are not shared and append in place instead of copying.
            var history = processes.removeValue(forKey: process.id) ?? ProcessHistory(capacity: size)
            history.cpu.append(process.cpuPercent.map { Float($0) } ?? .nan)
            history.memory.append(process.memoryForRanking.map { Float($0) } ?? .nan)
            next[process.id] = history
        }
        processes = next
    }

    /// Keeps the newest values that fit the new length.
    mutating func resize(to newCapacity: Int) {
        let size = max(2, newCapacity)
        guard size != capacity else { return }
        capacity = size
        for series in HistorySeries.allCases {
            system[series]?.resize(to: size)
        }
        levels.resize(to: size)
        let processSize = processCapacity
        for id in processes.keys {
            processes[id]?.cpu.resize(to: processSize)
            processes[id]?.memory.resize(to: processSize)
        }
    }

    func values(_ series: HistorySeries) -> [Double] {
        system[series]?.elements ?? []
    }

    func process(_ id: ProcessIdentity) -> ProcessHistorySnapshot? {
        processes[id]?.snapshot
    }

    var snapshot: HistorySnapshot {
        HistorySnapshot(
            capacity: capacity,
            series: Dictionary(uniqueKeysWithValues: HistorySeries.allCases.map { ($0, values($0)) }),
            pressureLevels: levels.elements
        )
    }
}
