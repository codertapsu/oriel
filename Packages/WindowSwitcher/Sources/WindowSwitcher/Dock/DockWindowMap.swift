/// Which windows each app icon in the Dock stands for (PLAN §7.1.12). An icon stands for the windows of every process
/// with its app's bundle ID. Several icons with one bundle ID are copies of the app (Xcode and Xcode-beta, a copy run
/// from a disk image) or one copy run more than once, which the Dock shows an icon per process for: each of those icons
/// stands for the processes running from its own bundle, and the icons of one bundle pair with its processes in the
/// order they started. Pure.
nonisolated enum DockWindowMap {
    /// A file as the file system knows it, whatever the path to it: a bundle reached through a symbolic link, as
    /// Safari's is in its cryptex, is the same file.
    struct FileID: Sendable, Hashable {
        var device: Int32
        var inode: UInt64
    }

    /// A running app's process; callers pass them in the order they started.
    struct Process: Sendable, Equatable {
        var pid: Int32
        var bundleID: String
        /// The bundle it runs from, needed only when several icons share its bundle ID.
        var file: FileID?
    }

    /// The windows of each app icon of `items`, by the icon's index, in `entries`' order (most recently used first).
    /// `bundleIDs` names each icon's app by index; an icon without one stands for nothing. `files` gives the bundle of
    /// each icon whose bundle ID another icon shares; such an icon without one stands for nothing either.
    static func windows(
        for items: [DockItem],
        bundleIDs: [Int: String],
        files: [Int: FileID],
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
            guard indices.count > 1 else {
                result[indices[0]] = entries.filter { $0.info.bundleID == bundleID }
                continue
            }
            var copies: [FileID: [Int]] = [:]
            for index in indices {
                if let file = files[index] {
                    copies[file, default: []].append(index)
                }
            }
            for (file, sameFile) in copies {
                let pids = processes.filter { $0.bundleID == bundleID && $0.file == file }.map(\.pid)
                if sameFile.count > 1, sameFile.count == pids.count {
                    for (index, pid) in zip(sameFile, pids) {
                        result[index] = entries.filter { $0.info.pid == pid }
                    }
                } else {
                    let windows = entries.filter { pids.contains($0.info.pid) }
                    for index in sameFile {
                        result[index] = windows
                    }
                }
            }
        }
        return result
    }
}
