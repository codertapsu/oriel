/// Which processes the list shows, and how: Activity Monitor's View menu.
nonisolated enum ViewFilter: String, CaseIterable, Sendable, Codable {
    case all
    case mine
    case system
    case otherUsers
    case apps
    case active
    case hierarchy
    case appsWithHelpers

    var title: String {
        switch self {
        case .all: "All Processes"
        case .mine: "My Processes"
        case .system: "System Processes"
        case .otherUsers: "Other User Processes"
        case .apps: "Apps"
        case .active: "Active Processes"
        case .hierarchy: "All Processes, Hierarchically"
        case .appsWithHelpers: "Apps with Their Helpers"
        }
    }

    var symbol: String {
        switch self {
        case .all: "list.bullet"
        case .mine: "person"
        case .system: "gearshape.2"
        case .otherUsers: "person.2"
        case .apps: "app"
        case .active: "waveform.path.ecg"
        case .hierarchy: "list.bullet.indent"
        case .appsWithHelpers: "square.stack.3d.up"
        }
    }

    /// Whether other users' processes can be listed, so `ps` has to run to measure them.
    var includesOtherUsers: Bool {
        switch self {
        case .mine, .apps: false
        default: true
        }
    }

    /// Hidden when Settings shows only the user's own processes.
    var isAboutOtherUsers: Bool {
        self == .system || self == .otherUsers
    }

    var isTree: Bool {
        self == .hierarchy || self == .appsWithHelpers
    }

    /// Whether `process` belongs in this view. "Active" means it used the processor, the disk or the network over the
    /// last interval.
    func includes(_ process: ProcessMetrics, myUID: UInt32) -> Bool {
        switch self {
        case .all, .hierarchy, .appsWithHelpers: true
        case .mine: process.uid == myUID
        case .system: process.uid == 0
        case .otherUsers: process.uid != 0 && process.uid != myUID
        case .apps: process.isApp
        case .active:
            (process.cpuPercent ?? 0) >= 0.1 || (process.diskPerSecond ?? 0) > 0 || (process.network?.total ?? 0) > 0
                || process.status == .running
        }
    }
}
