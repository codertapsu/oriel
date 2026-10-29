/// The Mac's network activity on its physical interfaces: totals since they came up, and per second over the last
/// interval.
nonisolated struct NetworkActivity: Sendable, Equatable, Codable {
    var bytes: TrafficBytes
    var packets: TrafficBytes
    var bytesPerSecond: TrafficRate
    var packetsPerSecond: TrafficRate
}
