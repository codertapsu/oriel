import Foundation

/// What is remembered of a finished scan, to say later what grew: the totals and the size of every folder worth
/// following, by path relative to the scanned folder. A few hundred kilobytes at most; the tree itself is not kept.
nonisolated struct ScanSnapshot: Codable, Sendable, Equatable, Identifiable {
    static let currentVersion = 1

    var version = ScanSnapshot.currentVersion
    var id = UUID()
    /// The folder or volume as the user chose it.
    var rootPath: String
    var displayName: String
    var date: Date
    var totalBytes: Int64
    var files: Int
    var folders: Int
    /// Relative path (`""` for the scanned folder itself) → bytes.
    var folderSizes: [String: Int64]

    /// - Parameters:
    ///   - minimumBytes: folders smaller than this, or than a two-thousandth of the total, are not followed.
    ///   - maximumEntries: the largest folders are kept, at most this many.
    static func make(
        from tree: ScanTree,
        rootPath: String,
        displayName: String,
        date: Date,
        minimumBytes: Int64 = 10_000_000,
        maximumEntries: Int = 4000,
        maximumDepth: Int = 8
    ) -> ScanSnapshot {
        let total = tree.root.size
        let threshold = max(minimumBytes, total / 2000)
        var sizes: [(path: String, size: Int64)] = [("", total)]
        var stack: [(index: Int32, path: String, depth: Int)] = [(ScanTree.rootIndex, "", 0)]
        while let (index, path, depth) = stack.popLast() {
            guard depth < maximumDepth else { continue }
            for child in tree.children(of: index) {
                let node = tree[child]
                guard node.kind.isContainer, node.size >= threshold else { continue }
                let childPath = path.isEmpty ? tree.name(of: child) : path + "/" + tree.name(of: child)
                sizes.append((childPath, node.size))
                stack.append((child, childPath, depth + 1))
            }
        }
        let kept = sizes.sorted { $0.size > $1.size }.prefix(maximumEntries)
        return ScanSnapshot(
            rootPath: rootPath,
            displayName: displayName,
            date: date,
            totalBytes: total,
            files: Int(tree.root.fileCount),
            folders: Int(tree.root.folderCount),
            folderSizes: Dictionary(kept.map { ($0.path, $0.size) }, uniquingKeysWith: max)
        )
    }
}
