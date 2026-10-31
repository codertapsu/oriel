/// Changes after a scan: items moved to the Trash or deleted, and folders read again after the file system reported a
/// change. Removed nodes stay in the array, marked, until `compacted()` drops them.
nonisolated extension ScanTree {
    /// Takes `index` and everything below it out of the tree and updates the totals above it. The root stays. A file with
    /// several hard links counted there waits to be counted at another link (`foldersToRecount()`).
    mutating func remove(_ index: Int32) {
        guard index != ScanTree.rootIndex, contains(index) else { return }
        let parent = nodes[Int(index)].parent
        unlink(index, from: parent)
        noteRemoved(markRemoved(index))
        recomputeTotals(dirty: [parent])
    }

    /// Replaces what `folder` holds directly with `digest`, a fresh listing of it. Subfolders that are still there
    /// keep their contents unless `keepsSubfolders` is false, except those read as an administrator, which always do:
    /// the user's rights cannot read them again. What goes is taken out before the listing's files with several hard
    /// links are counted (`merge(_:into:)`), so a file counted only in what went is counted again here. New folders are
    /// returned to be read, and must then be passed to `recomputeTotals(dirty:)` with `folder` once read.
    mutating func replaceContents(
        of folder: Int32,
        with digest: inout DirectoryDigest,
        keepsSubfolders: Bool = true
    ) -> [(index: Int32, item: DirectoryDigest.Item)] {
        guard contains(folder), nodes[Int(folder)].kind.isContainer else { return [] }
        var listed: [String: ScanNodeKind] = [:]
        for item in digest.items where item.kind.isContainer {
            listed[item.name] = item.kind
        }
        var kept: [String: Int32] = [:]
        // The system and "Other space" blocks of a volume's scan are not on disk, and the folder of macOS's own volumes is
        // read from elsewhere, so a listing never has them.
        var blocks: [Int32] = []
        var child = nodes[Int(folder)].firstChild
        var removed = 0
        while child != ScanNode.none {
            let node = nodes[Int(child)]
            let next = node.nextSibling
            let name = names[Int(node.name)]
            let staysIfListed = node.kind.isContainer && (keepsSubfolders || node.flags.contains(.readAsAdministrator))
            if node.kind == .system || node.kind == .unaccounted || anchors[child] != nil {
                blocks.append(child)
            } else if staysIfListed, listed[name] == node.kind, kept[name] == nil {
                kept[name] = child
            } else {
                removed += markRemoved(child)
            }
            child = next
        }
        var node = nodes[Int(folder)]
        node.firstChild = ScanNode.none
        node.flags.subtract(UnreadableReason.allFlags.union(.partial))
        setNode(node, at: folder)
        var next: [(index: Int32, item: DirectoryDigest.Item)] = []
        for item in digest.items {
            if item.kind.isContainer, let existing = kept.removeValue(forKey: item.name) {
                relink(existing, to: folder, flags: item.flags)
                continue
            }
            let index = append(item, to: folder)
            if item.descends {
                next.append((index, item))
            }
        }
        appendLinksAndSmallFiles(of: &digest, to: folder)
        for block in blocks {
            relink(block, to: folder, flags: nodes[Int(block)].flags)
        }
        noteRemoved(removed)
        return next
    }

    /// A copy without the removed nodes, renumbered, with its hard links' counters renumbered too. Its `generation` is
    /// one higher.
    func compacted() -> ScanTree {
        var renumbered: [Int32: Int32] = [ScanTree.rootIndex: ScanTree.rootIndex]
        var kept: [ScanNode] = [nodes[0]]
        kept.reserveCapacity(nodes.count - removedCount)
        var stack: [Int32] = [ScanTree.rootIndex]
        while let current = stack.popLast() {
            var child = nodes[Int(current)].firstChild
            while child != ScanNode.none {
                renumbered[child] = Int32(kept.count)
                kept.append(nodes[Int(child)])
                stack.append(child)
                child = nodes[Int(child)].nextSibling
            }
        }
        for index in kept.indices {
            var node = kept[index]
            node.parent = node.parent == ScanNode.none ? ScanNode.none : renumbered[node.parent] ?? ScanNode.none
            node.firstChild = node.firstChild == ScanNode.none ? ScanNode.none : renumbered[node.firstChild] ?? ScanNode.none
            node.nextSibling = node.nextSibling == ScanNode.none ? ScanNode.none : renumbered[node.nextSibling] ?? ScanNode.none
            kept[index] = node
        }
        var copy = self
        let movedAnchors = anchors.compactMap { index, path in renumbered[index].map { ($0, path) } }
        copy.replaceStorage(
            nodes: kept,
            names: names,
            removedCount: 0,
            anchors: Dictionary(uniqueKeysWithValues: movedAnchors),
            hardLinks: hardLinks.renumbered(by: renumbered)
        )
        return copy
    }

    /// Whether enough of the array is removed nodes that `compacted()` is worth its cost.
    var needsCompaction: Bool {
        removedCount > 50000 && removedCount * 3 > count
    }

    private mutating func unlink(_ index: Int32, from parent: Int32) {
        var parentNode = nodes[Int(parent)]
        if parentNode.firstChild == index {
            parentNode.firstChild = nodes[Int(index)].nextSibling
            setNode(parentNode, at: parent)
            return
        }
        var previous = parentNode.firstChild
        while previous != ScanNode.none {
            var previousNode = nodes[Int(previous)]
            if previousNode.nextSibling == index {
                previousNode.nextSibling = nodes[Int(index)].nextSibling
                setNode(previousNode, at: previous)
                return
            }
            previous = previousNode.nextSibling
        }
    }

    /// Puts a kept subfolder back as a child of `folder`.
    private mutating func relink(_ index: Int32, to folder: Int32, flags: ScanNodeFlags) {
        var node = nodes[Int(index)]
        node.nextSibling = nodes[Int(folder)].firstChild
        node.flags = node.flags.subtracting([.hidden, .excluded, .mountPoint, .firmlink, .cloudOnly]).union(flags)
        setNode(node, at: index)
        var parent = nodes[Int(folder)]
        parent.firstChild = index
        setNode(parent, at: folder)
    }

    /// Marks `index` and everything below it removed; returns how many nodes that was.
    private mutating func markRemoved(_ index: Int32) -> Int {
        var count = 0
        var stack: [Int32] = [index]
        while let current = stack.popLast() {
            var node = nodes[Int(current)]
            guard !node.isRemoved else { continue }
            node.flags.insert(.removed)
            setNode(node, at: current)
            count += 1
            var child = node.firstChild
            while child != ScanNode.none {
                stack.append(child)
                child = nodes[Int(child)].nextSibling
            }
        }
        return count
    }
}
