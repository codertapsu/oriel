/// The result of a scan: every folder, every file at or above the small-file threshold, and one aggregate of the
/// smaller files per folder, as compact nodes in one array.
///
/// A node's children always have higher indices than the node, so totals are summed in one backward pass. Children
/// are a linked list, so a folder's contents can be replaced (a rescan after a change, a file moved to the Trash)
/// without moving other nodes; removed nodes stay until `compacted()`. Names are interned. A value type: the scanner
/// edits its copy, and the window keeps the one it last received.
nonisolated struct ScanTree: Sendable {
    static let rootIndex: Int32 = 0

    private(set) var nodes: [ScanNode]
    private(set) var names: [String]
    /// Name → index while building or editing; dropped when a scan finishes, and rebuilt on the next edit.
    private var nameIndex: [String: Int32]?
    /// The folder that was read: `/System/Volumes/Data` for the startup volume.
    let rootPath: String
    /// How paths are shown and checked: through the firmlinks, for the startup volume.
    let firmlinks: FirmlinkMap
    /// Bumped when node indices change, so whoever holds an index looks it up again by path.
    private(set) var generation = 0
    /// Removed nodes still in the array.
    private(set) var removedCount = 0

    init(rootName: String, rootPath: String, firmlinks: FirmlinkMap = .empty) {
        self.rootPath = rootPath
        self.firmlinks = firmlinks
        // Index 1 is the empty name of the aggregates of smaller files; a root with no name shares it.
        names = [rootName, ""]
        var index: [String: Int32] = ["": 1]
        index[rootName] = rootName.isEmpty ? 1 : 0
        nameIndex = index
        nodes = [ScanNode(name: 0, parent: ScanNode.none, kind: .folder)]
    }

    var count: Int {
        nodes.count
    }

    var root: ScanNode {
        nodes[0]
    }

    subscript(index: Int32) -> ScanNode {
        nodes[Int(index)]
    }

    func contains(_ index: Int32) -> Bool {
        index >= 0 && Int(index) < nodes.count && !nodes[Int(index)].isRemoved
    }

    func name(of index: Int32) -> String {
        names[Int(nodes[Int(index)].name)]
    }

    // MARK: Building

    /// Adds `item` as a child of `parent` and returns its index.
    @discardableResult
    mutating func append(_ item: DirectoryDigest.Item, to parent: Int32) -> Int32 {
        var node = ScanNode(name: intern(item.name), parent: parent, kind: item.kind)
        node.size = item.size
        node.logicalSize = item.logicalSize
        node.fileCount = item.kind == .file ? 1 : 0
        node.created = item.created
        node.modified = item.modified
        node.accessed = item.accessed
        node.category = item.category
        node.flags = item.flags
        return link(node, to: parent)
    }

    /// Adds the aggregate of a folder's smaller files, if it has any.
    mutating func append(_ small: DirectoryDigest.SmallFiles, to parent: Int32) {
        guard small.count > 0 else { return }
        var node = ScanNode(name: 1, parent: parent, kind: .smallFiles)
        node.size = small.size
        node.logicalSize = small.logicalSize
        node.fileCount = Int32(clamping: small.count)
        node.modified = small.newest
        link(node, to: parent)
    }

    /// Adds a node that stands for space rather than files: the macOS system block, or what no file accounts for.
    @discardableResult
    mutating func appendSynthetic(_ kind: ScanNodeKind, name: String, size: Int64, to parent: Int32 = rootIndex) -> Int32 {
        var node = ScanNode(name: intern(name), parent: parent, kind: kind)
        node.size = size
        node.logicalSize = size
        return link(node, to: parent)
    }

    /// Adds everything `digest` keeps to `folder`, and returns the folders to read next with what they inherit.
    mutating func merge(_ digest: DirectoryDigest, into folder: Int32) -> [(index: Int32, item: DirectoryDigest.Item)] {
        var next: [(index: Int32, item: DirectoryDigest.Item)] = []
        for item in digest.items {
            let index = append(item, to: folder)
            if item.descends {
                next.append((index, item))
            }
        }
        append(digest.small, to: folder)
        return next
    }

    mutating func insertFlags(_ flags: ScanNodeFlags, at index: Int32) {
        nodes[Int(index)].flags.formUnion(flags)
    }

    mutating func setRootDates(created: Int32, modified: Int32, accessed: Int32) {
        nodes[0].created = created
        nodes[0].modified = modified
        nodes[0].accessed = accessed
    }

    /// Frees the name index; the next edit rebuilds it.
    mutating func finishBuilding() {
        nameIndex = nil
    }

    // MARK: Totals

    /// Sums every folder from its children, in one backward pass.
    mutating func computeTotals() {
        for index in nodes.indices where nodes[index].kind.isContainer {
            resetTotals(at: index)
        }
        for index in stride(from: nodes.count - 1, to: 0, by: -1) where !nodes[index].isRemoved {
            addTotals(of: index, to: Int(nodes[index].parent))
        }
    }

    /// Sums `dirty` folders and their ancestors again from their children, after an edit. A folder's children are
    /// either untouched or dirty themselves with higher indices, so going backwards leaves every total right.
    mutating func recomputeTotals(dirty: Set<Int32>) {
        var all = Set<Int32>()
        for index in dirty where contains(index) {
            var current = index
            while current != ScanNode.none, all.insert(current).inserted {
                current = nodes[Int(current)].parent
            }
        }
        for index in all.sorted(by: >) where nodes[Int(index)].kind.isContainer {
            resetTotals(at: Int(index))
            var child = nodes[Int(index)].firstChild
            while child != ScanNode.none {
                addTotals(of: Int(child), to: Int(index))
                child = nodes[Int(child)].nextSibling
            }
        }
    }

    private mutating func resetTotals(at index: Int) {
        nodes[index].size = 0
        nodes[index].logicalSize = 0
        nodes[index].fileCount = 0
        nodes[index].folderCount = 0
    }

    private mutating func addTotals(of child: Int, to parent: Int) {
        let node = nodes[child]
        nodes[parent].size += node.size
        nodes[parent].logicalSize += node.logicalSize
        nodes[parent].fileCount &+= node.fileCount
        nodes[parent].folderCount &+= node.folderCount &+ (node.kind.isContainer ? 1 : 0)
    }

    // MARK: Internals shared with the editing extension

    @discardableResult
    mutating func link(_ node: ScanNode, to parent: Int32) -> Int32 {
        var node = node
        let index = Int32(nodes.count)
        node.parent = parent
        node.nextSibling = nodes[Int(parent)].firstChild
        nodes[Int(parent)].firstChild = index
        nodes.append(node)
        return index
    }

    mutating func intern(_ name: String) -> Int32 {
        if nameIndex == nil {
            var index: [String: Int32] = [:]
            index.reserveCapacity(names.count)
            for (position, name) in names.enumerated() where index[name] == nil {
                index[name] = Int32(position)
            }
            nameIndex = index
        }
        if let known = nameIndex?[name] {
            return known
        }
        let index = Int32(names.count)
        names.append(name)
        nameIndex?[name] = index
        return index
    }

    mutating func setNode(_ node: ScanNode, at index: Int32) {
        nodes[Int(index)] = node
    }

    mutating func noteRemoved(_ count: Int) {
        removedCount += count
    }

    mutating func replaceStorage(nodes: [ScanNode], names: [String], removedCount: Int) {
        self.nodes = nodes
        self.names = names
        self.removedCount = removedCount
        nameIndex = nil
        generation += 1
    }
}
