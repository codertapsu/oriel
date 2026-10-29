/// The Mac's disk activity: totals since each disk appeared, and per second over the last interval.
nonisolated struct DiskActivity: Sendable, Equatable, Codable {
    var totals: DiskCounters
    var readBytesPerSecond: Double
    var writtenBytesPerSecond: Double
    var readsPerSecond: Double
    var writesPerSecond: Double
}
