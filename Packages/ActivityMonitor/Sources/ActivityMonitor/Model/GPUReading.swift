import Foundation

/// One graphics processor's utilization, from its `IOAccelerator`'s `PerformanceStatistics`. Best effort: the key is
/// not documented, and a GPU that does not report it is left out.
nonisolated struct GPUReading: Sendable, Equatable, Codable {
    let name: String
    /// 0–100.
    let utilization: Double

    init(name: String, utilization: Double) {
        self.name = name
        self.utilization = min(100, max(0, utilization))
    }

    init?(name: String, performanceStatistics: [String: Any]) {
        guard let value = performanceStatistics["Device Utilization %"] as? NSNumber else { return nil }
        self.init(name: name, utilization: value.doubleValue)
    }
}
