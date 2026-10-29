/// A copy of the Mac-wide history for the main thread, oldest first.
nonisolated struct HistorySnapshot: Sendable, Equatable {
    /// How many samples the graphs span when full.
    var capacity: Int
    var series: [HistorySeries: [Double]]
    /// The pressure level of each sample, which colours the memory graph.
    var pressureLevels: [MemoryPressure.Level]

    static let empty = HistorySnapshot(capacity: 2, series: [:], pressureLevels: [])

    func values(_ series: HistorySeries) -> [Double] {
        self.series[series] ?? []
    }
}
