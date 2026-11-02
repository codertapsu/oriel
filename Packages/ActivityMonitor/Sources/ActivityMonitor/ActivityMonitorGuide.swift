import OrielCore

public extension FeatureGuide {
    /// Activity Monitor's page in the feature tour (PLAN §19).
    nonisolated static let activityMonitor = FeatureGuide(
        id: ModuleID.activityMonitor.rawValue,
        title: "Activity Monitor",
        symbol: "gauge.with.dots.needle.67percent",
        summary: "See what your Mac is doing: every app and process, with its CPU, memory, energy, disk and network use.",
        highlights: [
            Highlight("Five measures", "CPU, Memory, Energy, Disk and Network, each sorted your way."),
            Highlight("Heavy use", "A flame marks a process over its limit, so it stands out."),
            Highlight("Details", "Live graphs, the code signature, and a process's open files and connections."),
            Highlight("Quit safely", "Quit or force quit a process after Oriel says what that does."),
        ],
        commandID: "openActivityMonitor"
    )
}
