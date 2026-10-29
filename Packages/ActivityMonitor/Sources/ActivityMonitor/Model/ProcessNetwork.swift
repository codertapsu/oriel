/// A process's traffic as one `nettop` run lists it: each open connection with its bytes.
///
/// nettop counts only connections that are still open (or just closed), so a process's own total can go down between
/// two runs. Rates are therefore summed per connection: a connection seen in both runs adds what it carried in
/// between, and a new one adds everything it carried.
nonisolated struct ProcessNetwork: Sendable, Equatable {
    /// Keyed by nettop's description, `tcp4 10.0.0.2:52167<->17.57.145.54:443`; repeats get `#2`, `#3`.
    var connections: [String: TrafficBytes]
    /// nettop's line for the process.
    var total: TrafficBytes

    init(connections: [String: TrafficBytes] = [:], total: TrafficBytes = .zero) {
        self.connections = connections
        self.total = total
    }

    /// The bytes carried since `earlier`, the same process in the previous run, or everything when it had no line then.
    func added(since earlier: ProcessNetwork?) -> TrafficBytes {
        guard !connections.isEmpty else {
            return earlier.map { total.added(since: $0.total) } ?? total
        }
        return connections.reduce(TrafficBytes.zero) { sum, entry in
            sum + entry.value.added(since: earlier?.connections[entry.key] ?? .zero)
        }
    }
}
