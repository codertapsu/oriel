/// The kind of a processor core, as the device tree's `cluster-type` names it on Apple silicon.
nonisolated enum CoreType: String, Sendable, Codable {
    case performance
    case efficiency
    /// Intel Macs, whose cores are all alike.
    case standard

    init(clusterType: String) {
        switch clusterType.uppercased() {
        case "P": self = .performance
        case "E": self = .efficiency
        default: self = .standard
        }
    }

    /// "P" or "E" under a core's bar.
    var letter: String {
        switch self {
        case .performance: "P"
        case .efficiency: "E"
        case .standard: ""
        }
    }

    var title: String {
        switch self {
        case .performance: "Performance"
        case .efficiency: "Efficiency"
        case .standard: "Core"
        }
    }

    /// The core types in `host_processor_info` order when the device tree cannot be read: Apple silicon numbers its
    /// efficiency cores first. `levels` are the `hw.perflevelN` counts, performance first, as the sysctls give them.
    static func fallback(levels: [(name: String, cores: Int)], total: Int) -> [CoreType] {
        guard levels.count > 1 else { return Array(repeating: .standard, count: total) }
        let types = levels.reversed().flatMap { level in
            Array(repeating: level.name.lowercased().hasPrefix("eff") ? CoreType.efficiency : .performance, count: level.cores)
        }
        return types.count == total ? types : Array(repeating: .standard, count: total)
    }
}
