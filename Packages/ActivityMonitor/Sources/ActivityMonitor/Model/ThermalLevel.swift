import Foundation

/// `ProcessInfo.thermalState`, which macOS raises as the Mac heats up and slows itself down.
nonisolated enum ThermalLevel: String, Sendable, Codable {
    case nominal
    case fair
    case serious
    case critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }

    var title: String {
        switch self {
        case .nominal: "Normal"
        case .fair: "Warm"
        case .serious: "Hot, slowed down"
        case .critical: "Very hot, slowed down"
        }
    }

    /// Whether macOS is holding the processor back to cool it.
    var isThrottling: Bool {
        self == .serious || self == .critical
    }
}
