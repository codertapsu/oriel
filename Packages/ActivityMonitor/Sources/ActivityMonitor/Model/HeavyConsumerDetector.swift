/// Finds the processes using more than the thresholds allow: CPU, disk or network over their limit for the whole of
/// `HeavyThresholds.seconds`, or memory over its limit now. It remembers only when each process crossed a limit, and
/// forgets processes that ended.
nonisolated struct HeavyConsumerDetector: Sendable {
    enum Rate: CaseIterable, Sendable {
        case cpu
        case disk
        case network

        var flag: HeavyFlags {
            switch self {
            case .cpu: .cpu
            case .disk: .disk
            case .network: .network
            }
        }
    }

    var thresholds: HeavyThresholds
    /// When each process went over each rate limit, in nanoseconds of uptime.
    private var overSince: [ProcessIdentity: [Rate: UInt64]] = [:]

    init(thresholds: HeavyThresholds = HeavyThresholds()) {
        self.thresholds = thresholds
    }

    /// Takes one sample whose rates cover `start` to `end` and returns the flags of each process over a threshold. A rate
    /// that is unknown this time (another user's CPU while `ps` did not run) starts the wait again.
    mutating func update(_ processes: [ProcessMetrics], from start: UInt64, to end: UInt64) -> [ProcessIdentity: HeavyFlags] {
        let needed = UInt64(max(0, thresholds.seconds) * 1_000_000_000)
        var flags: [ProcessIdentity: HeavyFlags] = [:]
        var next: [ProcessIdentity: [Rate: UInt64]] = [:]
        for process in processes {
            var heavy: HeavyFlags = (process.memoryForRanking ?? 0) >= thresholds.memoryBytes ? .memory : []
            // Most processes are under every rate limit: they need no bookkeeping.
            guard Rate.allCases.contains(where: { (value(of: $0, for: process) ?? 0) >= limit(of: $0) }) else {
                if !heavy.isEmpty {
                    flags[process.id] = heavy
                }
                continue
            }
            var since = overSince[process.id] ?? [:]
            for rate in Rate.allCases {
                guard let value = value(of: rate, for: process), value >= limit(of: rate) else {
                    since[rate] = nil
                    continue
                }
                let began = since[rate] ?? start
                since[rate] = began
                if end >= began, end - began >= needed {
                    heavy.insert(rate.flag)
                }
            }
            if !since.isEmpty {
                next[process.id] = since
            }
            if !heavy.isEmpty {
                flags[process.id] = heavy
            }
        }
        overSince = next
        return flags
    }

    mutating func reset() {
        overSince = [:]
    }

    private func value(of rate: Rate, for process: ProcessMetrics) -> Double? {
        switch rate {
        case .cpu: process.cpuPercent
        case .disk: process.diskPerSecond
        case .network: process.network?.total
        }
    }

    private func limit(of rate: Rate) -> Double {
        switch rate {
        case .cpu: thresholds.cpuPercent
        case .disk: thresholds.diskBytesPerSecond
        case .network: thresholds.networkBytesPerSecond
        }
    }
}
