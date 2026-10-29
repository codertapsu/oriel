/// Reading the tree: children, files below a folder, search.
nonisolated extension ScanTree {
    func children(of index: Int32) -> [Int32] {
        var result: [Int32] = []
        var child = nodes[Int(index)].firstChild
        while child != ScanNode.none {
            result.append(child)
            child = nodes[Int(child)].nextSibling
        }
        return result
    }

    /// Children, largest first; ties by name, so the order is stable.
    func childrenBySize(of index: Int32) -> [Int32] {
        children(of: index).sorted { lhs, rhs in
            let left = nodes[Int(lhs)]
            let right = nodes[Int(rhs)]
            if left.size != right.size {
                return left.size > right.size
            }
            return names[Int(left.name)] < names[Int(right.name)]
        }
    }

    /// Every node below `index` (not `index` itself) that `include` accepts, in no particular order.
    func descendants(of index: Int32, where include: (ScanNode) -> Bool) -> [Int32] {
        var result: [Int32] = []
        if index == ScanTree.rootIndex {
            // The whole tree: one pass over the array beats walking the lists.
            for position in 1 ..< nodes.count where !nodes[position].isRemoved && include(nodes[position]) {
                result.append(Int32(position))
            }
            return result
        }
        var stack = children(of: index)
        while let current = stack.popLast() {
            let node = nodes[Int(current)]
            if include(node) {
                result.append(current)
            }
            var child = node.firstChild
            while child != ScanNode.none {
                stack.append(child)
                child = nodes[Int(child)].nextSibling
            }
        }
        return result
    }

    /// The files kept one by one below `index`.
    func files(under index: Int32) -> [Int32] {
        descendants(of: index) { $0.kind == .file }
    }

    /// The `limit` largest files below `index`, largest first.
    func largestFiles(under index: Int32, limit: Int) -> [Int32] {
        let files = files(under: index)
        guard files.count > limit else {
            return files.sorted { nodes[Int($0)].size > nodes[Int($1)].size }
        }
        // A partial sort: keep a sorted window of the largest seen so far.
        var window: [Int32] = []
        window.reserveCapacity(limit + 1)
        for file in files {
            let size = nodes[Int(file)].size
            if window.count == limit, let last = window.last, size <= nodes[Int(last)].size {
                continue
            }
            let position = window.partitioningIndex { nodes[Int($0)].size < size }
            window.insert(file, at: position)
            if window.count > limit {
                window.removeLast()
            }
        }
        return window
    }

    /// Files and folders below `index` whose name contains every word of `query`, ignoring case and accents.
    func search(_ query: String, under index: Int32) -> [Int32] {
        let words = TextMatch.words(of: query)
        guard !words.isEmpty else { return [] }
        var matchingNames = Set<Int32>()
        for (position, name) in names.enumerated() where TextMatch.matches(name, words: words) {
            matchingNames.insert(Int32(position))
        }
        return descendants(of: index) { !$0.kind.isSynthetic && matchingNames.contains($0.name) }
    }
}
