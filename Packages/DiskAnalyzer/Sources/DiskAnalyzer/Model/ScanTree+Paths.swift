/// Paths and lookups. A node's path is built from its ancestors' names, so nothing stores a path per node.
nonisolated extension ScanTree {
    /// The nodes from the root down to `index`, both included.
    func lineage(of index: Int32) -> [Int32] {
        var chain: [Int32] = []
        var current = index
        while current != ScanNode.none {
            chain.append(current)
            current = nodes[Int(current)].parent
        }
        return chain.reversed()
    }

    /// Whether `ancestor` is `index` or above it.
    func isAncestor(_ ancestor: Int32, of index: Int32) -> Bool {
        var current = index
        while current != ScanNode.none {
            if current == ancestor {
                return true
            }
            current = nodes[Int(current)].parent
        }
        return false
    }

    /// The path on disk. An aggregate of smaller files and the synthetic nodes have their folder's path.
    func path(of index: Int32) -> String {
        var components: [String] = []
        var current = index
        while current != ScanTree.rootIndex, current != ScanNode.none {
            let node = nodes[Int(current)]
            if !node.kind.isSynthetic {
                components.append(names[Int(node.name)])
            }
            current = node.parent
        }
        guard !components.isEmpty else { return rootPath }
        let tail = components.reversed().joined(separator: "/")
        return rootPath == "/" ? "/" + tail : rootPath + "/" + tail
    }

    /// The path as the rest of macOS shows it: `/Users/me` rather than `/System/Volumes/Data/Users/me`.
    func displayPath(of index: Int32) -> String {
        firmlinks.visiblePath(for: path(of: index))
    }

    /// The node at `path`, given in either form; nil when it is not part of the scan.
    func index(ofPath path: String) -> Int32? {
        let candidates = [path, firmlinks.dataPath(for: path)]
        for candidate in candidates {
            if let index = walk(candidate) {
                return index
            }
        }
        return nil
    }

    /// The deepest node on the way to `path` that the scan has: the folder to read again after a change at `path`.
    func nearestIndex(toPath path: String) -> Int32? {
        for candidate in [path, firmlinks.dataPath(for: path)] {
            guard let relative = relativeComponents(of: candidate) else { continue }
            var current = ScanTree.rootIndex
            for component in relative {
                guard let next = child(named: component, of: current) else { break }
                current = next
            }
            return current
        }
        return nil
    }

    /// The child of `parent` named `name`, if there is one.
    func child(named name: some StringProtocol, of parent: Int32) -> Int32? {
        var child = nodes[Int(parent)].firstChild
        while child != ScanNode.none {
            let node = nodes[Int(child)]
            if !node.kind.isSynthetic, names[Int(node.name)] == name {
                return child
            }
            child = node.nextSibling
        }
        return nil
    }

    private func walk(_ path: String) -> Int32? {
        guard let relative = relativeComponents(of: path) else { return nil }
        var current = ScanTree.rootIndex
        for component in relative {
            guard let next = child(named: component, of: current) else { return nil }
            current = next
        }
        return current
    }

    private func relativeComponents(of path: String) -> [Substring]? {
        let trimmed = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
        if trimmed == rootPath {
            return []
        }
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        guard trimmed.hasPrefix(prefix) else { return nil }
        return trimmed.dropFirst(prefix.count).split(separator: "/")
    }
}
