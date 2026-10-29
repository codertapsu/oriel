/// What a column shows for one row.
nonisolated extension ActivityColumn {
    func text(for process: ProcessMetrics) -> String {
        switch self {
        case .name: process.name
        case .cpu: ActivityFormat.percent(process.cpuPercent)
        case .cpuTime: ActivityFormat.cpuTime(process.cpuTime)
        case .threads: ActivityFormat.count(process.threads)
        case .idleWakeups: ActivityFormat.perSecond(process.idleWakeupsPerSecond)
        case .kind: process.kind.title
        case .status: process.status?.title ?? ActivityFormat.dash
        case .pid: String(process.pid)
        case .user: process.user
        case .memory: ActivityFormat.memory(process.memoryForRanking)
        case .realMemory: ActivityFormat.memory(process.realMemory)
        case .power: ActivityFormat.power(process.power)
        case .preventingSleep: process.preventsSleep ? "Yes" : "No"
        case .diskWritten: ActivityFormat.bytes(process.diskWritten)
        case .diskRead: ActivityFormat.bytes(process.diskRead)
        case .diskWrittenRate: ActivityFormat.rate(process.diskWrittenPerSecond)
        case .diskReadRate: ActivityFormat.rate(process.diskReadPerSecond)
        case .sentRate: ActivityFormat.rate(process.network?.sent)
        case .receivedRate: ActivityFormat.rate(process.network?.received)
        case .sent: ActivityFormat.bytes(process.networkTotal?.sent)
        case .received: ActivityFormat.bytes(process.networkTotal?.received)
        }
    }

    /// The heavy-use flag a value in this column is highlighted for. Memory is judged by the footprint, so only the
    /// Memory column lights up.
    var heavyFlag: HeavyFlags? {
        switch self {
        case .cpu: .cpu
        case .memory: .memory
        case .diskWrittenRate, .diskReadRate: .disk
        case .sentRate, .receivedRate: .network
        default: nil
        }
    }

    /// Memory shows another user's resident set, all `ps` gives, in place of the footprint; such a value is dimmed.
    func isStandIn(for process: ProcessMetrics) -> Bool {
        self == .memory && process.memory == nil && process.realMemory != nil
    }

    /// A value of nothing at all (no CPU, no bytes), which the list draws quieter so the busy rows stand out.
    func isQuiet(for process: ProcessMetrics) -> Bool {
        switch self {
        case .cpu: (process.cpuPercent ?? 1) < 0.05
        case .idleWakeups: process.idleWakeupsPerSecond == 0
        case .power: (process.power ?? 1) < 0.0005
        case .diskWritten: process.diskWritten == 0
        case .diskRead: process.diskRead == 0
        case .diskWrittenRate: (process.diskWrittenPerSecond ?? 1) < 0.5
        case .diskReadRate: (process.diskReadPerSecond ?? 1) < 0.5
        case .sentRate: (process.network?.sent ?? 1) < 0.5
        case .receivedRate: (process.network?.received ?? 1) < 0.5
        case .sent: process.networkTotal?.sent == 0
        case .received: process.networkTotal?.received == 0
        case .preventingSleep: !process.preventsSleep
        default: false
        }
    }
}
