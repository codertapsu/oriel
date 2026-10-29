/// The Mac-wide values the summary graphs draw over time.
nonisolated enum HistorySeries: CaseIterable, Hashable, Sendable {
    case cpuUser
    case cpuSystem
    case memoryPressure
    case diskRead
    case diskWritten
    case networkReceived
    case networkSent
    case gpu
    case power
}
