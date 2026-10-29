import Foundation

/// How a list of files is ordered.
nonisolated struct FileSort: Sendable, Equatable {
    enum Key: String, Sendable, CaseIterable {
        case name, size, kind, created, modified, accessed, lastOpened, folder, items, share
    }

    var key: Key = .size
    var ascending = false

    /// Sorts `indices` of `tree`. `lastOpened` supplies Spotlight's dates where known; `folders` the parent paths,
    /// computed only for a sort by folder.
    func sorted(_ indices: [Int32], in tree: ScanTree, lastOpened: [Int32: Date] = [:]) -> [Int32] {
        let folders = key == .folder ? Dictionary(uniqueKeysWithValues: indices.map { ($0, tree.displayPath(of: tree[$0].parent)) }) : [:]
        return indices.sorted { lhs, rhs in
            let order = compare(lhs, rhs, in: tree, lastOpened: lastOpened, folders: folders)
            if order == .orderedSame {
                // Ties: largest first, then by index, so the order never jumps.
                let left = tree[lhs].size
                let right = tree[rhs].size
                return left != right ? left > right : lhs < rhs
            }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    private func compare(
        _ lhs: Int32,
        _ rhs: Int32,
        in tree: ScanTree,
        lastOpened: [Int32: Date],
        folders: [Int32: String]
    ) -> ComparisonResult {
        let left = tree[lhs]
        let right = tree[rhs]
        switch key {
        case .name:
            return tree.name(of: lhs).localizedStandardCompare(tree.name(of: rhs))
        case .size, .share:
            return Self.compare(left.size, right.size)
        case .items:
            return Self.compare(left.fileCount, right.fileCount)
        case .kind:
            return Self.compare(left.category.rawValue, right.category.rawValue)
        case .created:
            return Self.compare(left.created, right.created)
        case .modified:
            return Self.compare(left.modified, right.modified)
        case .accessed:
            return Self.compare(left.accessed, right.accessed)
        case .lastOpened:
            return Self.compare(lastOpened[lhs] ?? .distantPast, lastOpened[rhs] ?? .distantPast)
        case .folder:
            return (folders[lhs] ?? "").localizedStandardCompare(folders[rhs] ?? "")
        }
    }

    private static func compare<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        lhs < rhs ? .orderedAscending : lhs > rhs ? .orderedDescending : .orderedSame
    }
}
