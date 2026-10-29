/// How a shortcut orders the windows it shows (PLAN §7.1.11, the app-grouped preset).
nonisolated enum WindowGrouping: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Most recently used first.
    case ungrouped
    /// Each app's windows together, under the app's name: apps in the order of their most recent window, and each
    /// app's windows most recent first. A search keeps the best match first, with the rest of its app after it.
    case byApp

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .ungrouped: "Most recent first"
        case .byApp: "Grouped by app"
        }
    }
}
