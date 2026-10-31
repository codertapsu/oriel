/// Counts a file with several hard links once: the first link a scan reads carries the file's size, every other link of
/// the same file (same device and inode) is listed with none. It stays with the tree as long as the scan is open, so a
/// folder read again later, after a change or as an administrator, counts a link of a file counted elsewhere as a
/// further link too. Only files with more than one link are recorded, so it stays small.
///
/// It records which node carries each file's size: the link's own when it is kept one by one, else its folder's
/// smaller files. Both go when that folder is listed again or removed, and the file then waits for another link to
/// count it: the next listing of one does, and the smaller files that hold one are handed out to be read again
/// (`takeRecounts`).
nonisolated struct HardLinkRegistry: Sendable {
    /// A file: its volume's device number and its inode.
    struct Identity: Hashable, Sendable, Codable {
        var device: Int32
        var inode: UInt64
    }

    private struct Entry {
        /// The node that carries the file's size.
        var counter: Int32
        /// Smaller files, of another folder, that hold a further link of the file.
        var holder = ScanNode.none
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

    /// Records that `node`, smaller files, holds a further link of `file`, which is counted elsewhere.
    mutating func hold(_ file: Identity, at node: Int32) {
        entries[file]?.holder = node
    }

    /// The registry for a tree whose nodes were renumbered (`ScanTree.compacted()`): `map` gives each kept node's new
    /// index. A file whose counter and holder were both dropped is forgotten.
    func renumbered(by map: [Int32: Int32]) -> HardLinkRegistry {
        var renumbered = HardLinkRegistry()
        renumbered.entries.reserveCapacity(entries.count)
        for (file, entry) in entries {
            let counter = map[entry.counter] ?? ScanNode.none
            let holder = map[entry.holder] ?? ScanNode.none
            if counter != ScanNode.none || holder != ScanNode.none {
                renumbered.entries[file] = Entry(counter: counter, holder: holder)
            }
        }
        return renumbered
    }

    /// The smaller files holding a further link of a file whose counter `isLive` rejects: read again, their folder
    /// counts it. Each holder is handed out once; a file no live node holds is forgotten, so the next listing of one of
    /// its links counts it.
    mutating func takeRecounts(isLive: (Int32) -> Bool) -> Set<Int32> {
        var holders = Set<Int32>()
        var taken: [Identity] = []
        var forgotten: [Identity] = []
        for (file, entry) in entries where !isLive(entry.counter) {
            if isLive(entry.holder) {
                holders.insert(entry.holder)
                taken.append(file)
            } else {
                forgotten.append(file)
            }
        }
        for file in taken {
            entries[file]?.holder = ScanNode.none
        }
        for file in forgotten {
            entries[file] = nil
        }
        return holders
    }

    var count: Int {
        entries.count
    }
}
