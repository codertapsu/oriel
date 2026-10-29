/// How hard macOS is working to find memory: the level it reports (`kern.memorystatus_vm_pressure_level`, the same
/// levels `DispatchSource.makeMemoryPressureSource` announces) and, for the graph, the share of memory it does not count
/// as available (100 − `kern.memorystatus_level`).
nonisolated struct MemoryPressure: Sendable, Equatable, Codable {
    enum Level: String, Sendable, Codable {
        case normal
        case warning
        case critical

        /// The sysctl's values are the dispatch flags: 1 normal, 2 warning, 4 critical.
        init(sysctlValue: Int32) {
            switch sysctlValue {
            case 4...: self = .critical
            case 2 ..< 4: self = .warning
            default: self = .normal
            }
        }

        var title: String {
            switch self {
            case .normal: "Normal"
            case .warning: "Elevated"
            case .critical: "Critical"
            }
        }
    }

    let level: Level
    /// 0–100.
    let percent: Double

    init(level: Level, percent: Double) {
        self.level = level
        self.percent = min(100, max(0, percent))
    }

    init(levelValue: Int32, availablePercent: Int32?) {
        let level = Level(sysctlValue: levelValue)
        // Without the percentage, the level alone places the graph.
        let fallback: Double = switch level {
        case .normal: 20
        case .warning: 60
        case .critical: 90
        }
        self.init(level: level, percent: availablePercent.map { 100 - Double($0) } ?? fallback)
    }
}
