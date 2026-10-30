import Foundation

/// What `oriel disk scan` prints: the totals, the largest items of the folder and the largest files below it.
nonisolated struct ScanReport {
    var tree: ScanTree
    var summary: ScanSummary
    var target: ScanTarget
    var top: Int

    private var displayPath: String {
        target.requestedPath
    }

    private var children: [Int32] {
        Array(tree.childrenBySize(of: ScanTree.rootIndex).prefix(top))
    }

    private var files: [Int32] {
        tree.largestFiles(under: ScanTree.rootIndex, limit: top)
    }

    var text: String {
        var lines = [
            "\(displayPath): \(DiskFormat.bytes(tree.root.size)) in \(DiskFormat.count(summary.files, "file")) and "
                + "\(DiskFormat.count(summary.folders, "folder")), scanned in \(DiskFormat.duration(summary.duration))",
        ]
        if summary.unreadableFolders > 0 {
            lines.append(
                "\(DiskFormat.count(summary.unreadableFolders, "folder")) could not be read: \(summary.administratorFolders) only "
                    + "an administrator can open, \(summary.protectedFolders) protected by macOS."
            )
        }
        lines.append("")
        lines.append("Largest items:")
        lines += children.map { "  \(pad(DiskFormat.bytes(tree[$0].size)))  \(name(of: $0))" }
        lines.append("")
        lines.append("Largest files:")
        lines += files.map { "  \(pad(DiskFormat.bytes(tree[$0].size)))  \(tree.displayPath(of: $0))" }
        return lines.joined(separator: "\n")
    }

    var json: [String: Any] {
        var categories: [String: Any] = [:]
        for category in summary.categories.ranked {
            categories[String(describing: category)] = [
                "files": summary.categories.count(of: category), "bytes": summary.categories.bytes(of: category),
            ]
        }
        return [
            "path": displayPath,
            "name": target.displayName,
            "bytes": tree.root.size,
            "logicalBytes": tree.root.logicalSize,
            "files": summary.files,
            "folders": summary.folders,
            "unreadableFolders": summary.unreadableFolders,
            "administratorOnlyFolders": summary.administratorFolders,
            "protectedFolders": summary.protectedFolders,
            "cloudOnlyFiles": summary.cloudOnlyFiles,
            "cloudOnlyBytes": summary.cloudOnlyBytes,
            "seconds": Double(summary.duration.components.seconds) + Double(summary.duration.components.attoseconds) / 1e18,
            "largestItems": children.map(item),
            "largestFiles": files.map(file),
            "categories": categories,
        ]
    }

    private func item(_ node: Int32) -> [String: Any] {
        [
            "name": name(of: node),
            "path": tree.displayPath(of: node),
            "kind": CSVExporter.kind(of: tree[node]),
            "bytes": tree[node].size,
            "files": Int(tree[node].fileCount),
        ]
    }

    private func file(_ node: Int32) -> [String: Any] {
        [
            "path": tree.displayPath(of: node),
            "bytes": tree[node].size,
            "modified": tree[node].modifiedDate.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
        ]
    }

    private func name(of node: Int32) -> String {
        tree[node].kind == .smallFiles ? DiskFormat.smallFiles(Int(tree[node].fileCount)) : tree.name(of: node)
    }

    private func pad(_ text: String) -> String {
        String(repeating: " ", count: max(0, 9 - text.count)) + text
    }
}
