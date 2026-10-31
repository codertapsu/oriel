/// The kinds of the files each aggregate of smaller files sums, which its node has no room for: per category, how many
/// files and bytes, and how many of the files are further links of a file counted elsewhere. A scan sums File Types from
/// its listings as it reads them; after an edit of the tree, which takes files out as well as adding them, they are
/// summed again from the tree, from its files kept one by one and these (`ScanSummary.recountCategories(in:)`).
///
/// A scan has about one aggregate per folder, so they are kept compact: only aggregates that have files, each as a few
/// variable-length numbers, seven bits a byte: how far its node is from the one recorded before, which categories it
/// has (a bit each, and one for further links), each of those categories' files and bytes, then its further links. An
/// aggregate of one kind takes 5 bytes this way and one of four about 20, where a `CategoryTotals` takes over 200: on a
/// tree of folders of mixed kinds, under 5 bytes a node beside the node's 56. Like the nodes, the kinds of an aggregate
/// taken out of the tree stay until it is compacted (`renumbered(by:)`).
nonisolated struct SmallFileKinds: Sendable {
    /// The bit after the categories' that says an aggregate holds further links.
    private static let furtherLinksBit = UInt64(1) << UInt64(FileCategory.allCases.count)

    private var encoded: [UInt8] = []
    /// The node recorded last, which the next one's distance is from.
    private var lastNode: Int32 = 0

    /// The bytes it takes, for measuring.
    var byteCount: Int {
        encoded.count
    }

    /// Records what `small`, the aggregate at `node`, sums, if it has files: symbolic links and devices have no kind.
    mutating func record(_ small: DirectoryDigest.SmallFiles, at node: Int32) {
        let kinds = small.categories
        guard kinds.totalCount > 0 else { return }
        var mask: UInt64 = small.duplicateLinks > 0 ? Self.furtherLinksBit : 0
        for category in FileCategory.allCases where kinds.count(of: category) > 0 {
            mask |= Self.bit(category)
        }
        write(node: node)
        write(mask)
        for category in FileCategory.allCases where kinds.count(of: category) > 0 {
            write(Int64(kinds.count(of: category)))
            write(kinds.bytes(of: category))
        }
        if small.duplicateLinks > 0 {
            write(Int64(small.duplicateLinks))
        }
    }

    /// The kinds and further links of the aggregates `isLive` accepts, summed.
    func totals(isLive: (Int32) -> Bool) -> (categories: CategoryTotals, duplicateLinks: Int) {
        var categories = CategoryTotals()
        var duplicateLinks = 0
        var cursor = Cursor(encoded)
        while let node = cursor.nextNode() {
            let isCounted = isLive(node)
            let mask = cursor.next()
            for category in FileCategory.allCases where mask & Self.bit(category) != 0 {
                let count = cursor.nextInteger()
                let bytes = cursor.nextInteger()
                if isCounted {
                    categories.add(category, bytes: bytes, count: Int(count))
                }
            }
            if mask & Self.furtherLinksBit != 0 {
                let links = cursor.nextInteger()
                if isCounted {
                    duplicateLinks += Int(links)
                }
            }
        }
        return (categories, duplicateLinks)
    }

    /// The kinds for a tree whose nodes were renumbered (`ScanTree.compacted()`): `map` gives each kept node's new index.
    /// The kinds of an aggregate it dropped go with it.
    func renumbered(by map: [Int32: Int32]) -> SmallFileKinds {
        var kept: [(node: Int32, kinds: Range<Int>)] = []
        var cursor = Cursor(encoded)
        while let node = cursor.nextNode() {
            let start = cursor.position
            cursor.skipKinds()
            if let renumbered = map[node] {
                kept.append((renumbered, start ..< cursor.position))
            }
        }
        // In node order, so the distances stay short.
        var renumbered = SmallFileKinds()
        for (node, kinds) in kept.sorted(by: { $0.node < $1.node }) {
            renumbered.write(node: node)
            renumbered.encoded.append(contentsOf: encoded[kinds])
        }
        return renumbered
    }

    private static func bit(_ category: FileCategory) -> UInt64 {
        UInt64(1) << UInt64(category.rawValue)
    }

    /// Writes how far `node` is from the node recorded before, zigzagged so that a step back is short too.
    private mutating func write(node: Int32) {
        let distance = Int64(node) - Int64(lastNode)
        write((distance << 1) ^ (distance >> 63))
        lastNode = node
    }

    private mutating func write(_ number: Int64) {
        write(UInt64(bitPattern: number))
    }

    /// Writes `number` seven bits a byte, the lowest first; the top bit says another byte follows.
    private mutating func write(_ number: UInt64) {
        var rest = number
        while rest >= 0x80 {
            encoded.append(UInt8(truncatingIfNeeded: rest) | 0x80)
            rest >>= 7
        }
        encoded.append(UInt8(rest))
    }

    /// Reads the numbers back in the order they were written.
    private struct Cursor {
        let encoded: [UInt8]
        private(set) var position = 0
        private var node: Int32 = 0

        init(_ encoded: [UInt8]) {
            self.encoded = encoded
        }

        /// The next aggregate's node; nil at the end.
        mutating func nextNode() -> Int32? {
            guard position < encoded.count else { return nil }
            let zigzag = next()
            let distance = Int64(bitPattern: zigzag >> 1) ^ -Int64(bitPattern: zigzag & 1)
            node = Int32(truncatingIfNeeded: Int64(node) + distance)
            return node
        }

        /// Steps over an aggregate's kinds, which follow its node.
        mutating func skipKinds() {
            let mask = next()
            let categories = (mask & (SmallFileKinds.furtherLinksBit - 1)).nonzeroBitCount
            for _ in 0 ..< 2 * categories + (mask & SmallFileKinds.furtherLinksBit != 0 ? 1 : 0) {
                _ = next()
            }
        }

        mutating func nextInteger() -> Int64 {
            Int64(bitPattern: next())
        }

        mutating func next() -> UInt64 {
            var number: UInt64 = 0
            var shift: UInt64 = 0
            while position < encoded.count {
                let byte = encoded[position]
                position += 1
                number |= UInt64(byte & 0x7F) << shift
                guard byte & 0x80 != 0 else { break }
                shift += 7
            }
            return number
        }
    }
}
