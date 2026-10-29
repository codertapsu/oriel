/// When a process counts as a heavy consumer (Settings → Activity Monitor). Rates must stay over their threshold for
/// `seconds`, so a moment's spike is not flagged; memory counts at once.
nonisolated struct HeavyThresholds: Sendable, Equatable {
    /// Percent of one core.
    var cpuPercent: Double = 80
    var seconds: Double = 10
    var memoryBytes: UInt64 = 2_000_000_000
    var diskBytesPerSecond: Double = 50_000_000
    var networkBytesPerSecond: Double = 5_000_000
}
