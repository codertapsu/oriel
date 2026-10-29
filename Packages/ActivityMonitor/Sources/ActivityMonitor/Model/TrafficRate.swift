/// Received and sent per second.
nonisolated struct TrafficRate: Sendable, Equatable, Codable {
    var received: Double
    var sent: Double

    static let zero = TrafficRate(received: 0, sent: 0)

    init(received: Double, sent: Double) {
        self.received = received
        self.sent = sent
    }

    init(_ bytes: TrafficBytes, over seconds: Double) {
        self.init(received: Double(bytes.received) / seconds, sent: Double(bytes.sent) / seconds)
    }

    var total: Double {
        received + sent
    }
}
