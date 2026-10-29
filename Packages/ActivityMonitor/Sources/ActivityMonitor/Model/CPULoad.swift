/// How busy the processor was over an interval, as fractions of its time.
nonisolated struct CPULoad: Sendable, Equatable, Codable {
    /// User time, nice processes included.
    var user: Double
    var system: Double

    var busy: Double {
        min(1, user + system)
    }

    var idle: Double {
        max(0, 1 - user - system)
    }
}
