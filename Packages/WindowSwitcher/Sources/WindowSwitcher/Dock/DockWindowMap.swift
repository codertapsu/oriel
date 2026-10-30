/// Which windows each app icon in the Dock stands for (PLAN §7.1.12). An icon stands for the windows of every process
/// with its app's bundle ID. When an app runs more than once the Dock shows an icon per process, in the order they
/// started, and then each icon stands for its own process's windows. Pure.
nonisolated enum DockWindowMap {
    /// A running app's process; callers pass them in the order they started.
    struct Process: Sendable, Equatable {
        var pid: Int32
        var bundleID: String
    }

    /// The windows of each app icon of `items`, by the icon's index, in `entries`' order (most recently used first).
    /// `bundleIDs` names each icon's app by index; an icon without one stands for nothing.
    static func windows(
        for items: [DockItem],
        bundleIDs: [Int: String],
        processes: [Process],
        entries: [WindowEntry]
    ) -> [Int: [WindowEntry]] {
        var icons: [String: [Int]] = [:]
        for (index, item) in items.enumerated() where item.kind == .application {
            if let bundleID = bundleIDs[index] {
                icons[bundleID, default: []].append(index)
            }
        }
        var result: [Int: [WindowEntry]] = [:]
        for (bundleID, indices) in icons {
            let pids = processes.filter { $0.bundleID == bundleID }.map(\.pid)
            if indices.count > 1, indices.count == pids.count {
                for (index, pid) in zip(indices, pids) {
                    result[index] = entries.filter { $0.info.pid == pid }
                }
            } else {
                let windows = entries.filter { $0.info.bundleID == bundleID }
                for index in indices {
                    result[index] = windows
                }
            }
        }
        return result
    }
}
