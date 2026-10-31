/// Counts a file with several hard links once: the first link a scan reads carries the file's size, every other link of
/// the same file (same device and inode) is listed with none. It stays with the tree as long as the scan is open, so a
/// folder read again later, after a change or as an administrator, counts a link of a file counted elsewhere as a
/// further link too. Only files with more than one link are recorded, so it stays small.
///
/// It records which node carries each file's size: the link's own when it is kept one by one, else its folder's
/// smaller files. Both go when that folder is listed again or removed, and the file then waits for another link to
/// count it: the next listing of one does, and the smaller files that hold one, every one of them recorded, are handed
/// out to be read again, one at a time (`takeRecounts`).
nonisolated struct HardLinkRegistry: Sendable {
    /// A file: its volume's device number and its inode.
    struct Identity: Hashable, Sendable, Codable {
        var device: Int32
        var inode: UInt64
    }

    private struct Entry {
        /// The node that carries the file's size.
        var counter: Int32
        /// Smaller files that hold a further link of the file, oldest first: every one, since any of them may be the one
        /// left when the counted link goes. Most such files have two links, so one holder.
        var holders: [Int32] = []
    }

    private var entries: [Identity: Entry] = [:]

    /// The node that carries the size of `file`, if one was recorded; it may since have been removed from the tree.
    func counter(of file: Identity) -> Int32? {
        entries[file]?.counter
    }

    /// Records that `node` carries the size of `file`.
    mutating func count(_ file: Identity, at node: Int32) {
        entries[file, default: Entry(counter: node)].counter = node
    }

    /// Records that `node`, smaller files, holds a further link of `file`, which is counted elsewhere. The holders that
    /// `isLive` rejects are dropped, so a folder listed again, whose smaller files are a new node, holds the file once.
    mutating func hold(_ file: Identity, at node: Int32, isLive: (Int32) -> Bool) {
        entries[file]?.holders.removeAll { $0 == node || !isLive($0) }
        entries[file]?.holders.append(node)
    }

    /// The registry for a tree whose nodes were renumbered (`ScanTree.compacted()`): `map` gives each kept node's new
    /// index. The holders it dropped are forgotten, and so is a file whose counter and holders were all dropped.
    func renumbered(by map: [Int32: Int32]) -> HardLinkRegistry {
        var renumbered = HardLinkRegistry()
        renumbered.entries.reserveCapacity(entries.count)
        for (file, entry) in entries {
            let counter = map[entry.counter] ?? ScanNode.none
            let holders = entry.holders.compactMap { map[$0] }
            if counter != ScanNode.none || !holders.isEmpty {
                renumbered.entries[file] = Entry(counter: counter, holders: holders)
            }
        }
        return renumbered
    }

    /// The smaller files holding a further link of a file whose counter `isLive` rejects: read again, their folder
    /// counts it. One holder is handed out per file, the oldest `isLive` accepts, whose folder has not changed for the
    /// longest, and only once; the others wait, in case that folder no longer holds the link. A file no live node holds
    /// is forgotten, so the next listing of one of its links counts it.
    mutating func takeRecounts(isLive: (Int32) -> Bool) -> Set<Int32> {
        var handedOut = Set<Int32>()
        var waiting: [(file: Identity, holders: [Int32])] = []
        var forgotten: [Identity] = []
        for (file, entry) in entries where !isLive(entry.counter) {
            var holders = entry.holders.filter(isLive)
            guard !holders.isEmpty else {
                forgotten.append(file)
                continue
            }
            handedOut.insert(holders.removeFirst())
            waiting.append((file, holders))
        }
        for (file, holders) in waiting {
            entries[file]?.holders = holders
        }
        for file in forgotten {
            entries[file] = nil
        }
        return handedOut
    }

    var count: Int {
        entries.count
    }
}
