/// Bytes received and sent: on one connection, by one process or across the Mac.
nonisolated struct TrafficBytes: Sendable, Equatable, Codable {
    var received: UInt64
    var sent: UInt64

    static let zero = TrafficBytes(received: 0, sent: 0)

    static func + (lhs: TrafficBytes, rhs: TrafficBytes) -> TrafficBytes {
        TrafficBytes(received: lhs.received &+ rhs.received, sent: lhs.sent &+ rhs.sent)
    }

    /// What was added since `earlier`; a counter that went down (a connection that started again) adds nothing.
    func added(since earlier: TrafficBytes) -> TrafficBytes {
        TrafficBytes(
            received: received >= earlier.received ? received - earlier.received : 0,
            sent: sent >= earlier.sent ? sent - earlier.sent : 0
        )
    }
}
