/// The result of a scan: every folder, every file at or above the small-file threshold, and one aggregate of the
/// smaller files per folder, as compact nodes in one array.
///
/// A node's children always have higher indices than the node, so totals are summed in one backward pass. Children
/// are a linked list, so a folder's contents can be replaced (a rescan after a change, a file moved to the Trash)
/// without moving other nodes; removed nodes stay until `compacted()`. Names are interned. A file with several hard
/// links is counted once across every listing that goes into the tree (`hardLinks`). A value type: the scanner edits
/// its copy, and the window keeps the one it last received.
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
    /// Folders read from somewhere other than below `rootPath`, with that path: the folder of macOS's own volumes, read
    /// at `/` next to the startup volume's data volume (`MacOSVolumes`). Paths below one start there.
    private(set) var anchors: [Int32: String] = [:]
    /// Bumped when node indices change, so whoever holds an index looks it up again by path.
    private(set) var generation = 0
    /// Removed nodes still in the array.
    private(set) var removedCount = 0
    /// Where each file with several hard links is counted, for as long as the tree lives: every listing added to it,
    /// the scan's, a refresh's or Read as Administrator's, counts its links against it.
    private(set) var hardLinks = HardLinkRegistry()

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

    /// Adds the aggregate of a folder's smaller files, if it has any, and returns its index.
    @discardableResult
    mutating func append(_ small: DirectoryDigest.SmallFiles, to parent: Int32) -> Int32? {
        guard small.count > 0 else { return nil }
        var node = ScanNode(name: 1, parent: parent, kind: .smallFiles)
        node.size = small.size
        node.logicalSize = small.logicalSize
        node.fileCount = Int32(clamping: small.count)
        node.modified = small.newest
        return link(node, to: parent)
    }

    /// Adds a folder read from `path` rather than from below the root (`anchors`).
    @discardableResult
    mutating func appendAnchor(_ item: DirectoryDigest.Item, path: String, to parent: Int32 = rootIndex) -> Int32 {
        let index = append(item, to: parent)
        anchors[index] = path
        return index
    }

    /// Whether macOS's own volumes were read file by file, so they need no system block.
    var hasMacOSVolumes: Bool {
        anchors.keys.contains { contains($0) && nodes[Int($0)].flags.contains(.macOSVolume) }
    }

    /// Adds a node that stands for space rather than files: the macOS system block, or what no file accounts for.
    @discardableResult
    mutating func appendSynthetic(_ kind: ScanNodeKind, name: String, size: Int64, to parent: Int32 = rootIndex) -> Int32 {
        var node = ScanNode(name: intern(name), parent: parent, kind: kind)
        node.size = size
        node.logicalSize = size
        return link(node, to: parent)
    }

    /// Adds everything `digest` keeps to `folder`, and returns the folders to read next with what they inherit. Its files
    /// with several hard links are counted against those the tree counted already, and `digest` comes back with them
    /// counted, for the summary.
    mutating func merge(_ digest: inout DirectoryDigest, into folder: Int32) -> [(index: Int32, item: DirectoryDigest.Item)] {
        var next: [(index: Int32, item: DirectoryDigest.Item)] = []
        for item in digest.items {
            let index = append(item, to: folder)
            if item.descends {
                next.append((index, item))
            }
        }
        appendLinksAndSmallFiles(of: &digest, to: folder)
        return next
    }

    /// Adds `digest`'s files with several hard links and its smaller files to `folder`, after its other items. A file the
    /// tree has not counted, or whose counted link is no longer in it, is counted at its first link here; any other link
    /// gets no size. The node that carries the size is recorded, and smaller files with a further link as holding it.
    mutating func appendLinksAndSmallFiles(of digest: inout DirectoryDigest, to folder: Int32) {
        var summed: [HardLinkRegistry.Identity] = []
        var held: [HardLinkRegistry.Identity] = []
        var countedHere = Set<HardLinkRegistry.Identity>()
        let links = digest.links
        digest.links = []
        for link in links {
            let isCounted = hardLinks.counter(of: link.file).map(contains) ?? false
            let isFirstLink = !isCounted && countedHere.insert(link.file).inserted
            if let item = digest.count(link, isFirstLink: isFirstLink) {
                hardLinks.count(link.file, at: append(item, to: folder))
            } else if isFirstLink {
                summed.append(link.file)
            } else {
                held.append(link.file)
            }
        }
        guard let small = append(digest.small, to: folder) else { return }
        for file in summed {
            hardLinks.count(file, at: small)
        }
        for file in held {
            hardLinks.hold(file, at: small)
        }
    }

    /// The folders to read again because their smaller files hold a further link of a file whose counted link has left
    /// the tree: deleted, moved, or no longer in its folder's listing. Read again, one of them counts the file. Each
    /// folder is handed out once for a file; a file no folder holds is forgotten, so the next listing of a link counts it.
    mutating func foldersToRecount() -> Set<Int32> {
        let holders = hardLinks.takeRecounts(isLive: contains)
        return Set(holders.map { nodes[Int($0)].parent }.filter(contains))
    }

    mutating func insertFlags(_ flags: ScanNodeFlags, at index: Int32) {
        nodes[Int(index)].flags.formUnion(flags)
    }

    mutating func removeFlags(_ flags: ScanNodeFlags, at index: Int32) {
        nodes[Int(index)].flags.subtract(flags)
    }

    /// Marks a folder unreadable for `reason`, in place of whatever reason it had.
    mutating func setUnreadable(_ reason: UnreadableReason, at index: Int32) {
        removeFlags(UnreadableReason.allFlags, at: index)
        insertFlags(reason.flags, at: index)
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

    mutating func replaceStorage(
        nodes: [ScanNode],
        names: [String],
        removedCount: Int,
        anchors: [Int32: String],
        hardLinks: HardLinkRegistry
    ) {
        self.nodes = nodes
        self.names = names
        self.removedCount = removedCount
        self.anchors = anchors
        self.hardLinks = hardLinks
        nameIndex = nil
        generation += 1
    }
}
