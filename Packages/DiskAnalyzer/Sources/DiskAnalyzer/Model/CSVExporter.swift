import Foundation

/// Export as CSV (RFC 4180): one row per item, sizes in bytes and dates in ISO 8601, so a spreadsheet can sort and sum
/// them. Names that a spreadsheet would run as a formula are prefixed with an apostrophe.
nonisolated enum CSVExporter {
    static let header = ["Path", "Name", "Kind", "Size (bytes)", "Content size (bytes)", "Files", "Modified", "Created", "Last accessed"]

    static func csv(_ rows: [Int32], in tree: ScanTree) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var lines = [header.map(field).joined(separator: ",")]
        lines.reserveCapacity(rows.count + 1)
        for index in rows where tree.contains(index) {
            let node = tree[index]
            let columns = [
                tree.displayPath(of: index),
                displayName(of: index, in: tree),
                kind(of: node),
                String(node.size),
                String(node.logicalSize),
                String(node.fileCount),
                node.modifiedDate.map(formatter.string(from:)) ?? "",
                node.createdDate.map(formatter.string(from:)) ?? "",
                node.accessedDate.map(formatter.string(from:)) ?? "",
            ]
            lines.append(columns.map(field).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// One field: quoted when it holds a comma, a quote or a line break, with quotes doubled.
    static func field(_ value: String) -> String {
        var value = value
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func kind(of node: ScanNode) -> String {
        switch node.kind {
        case .folder: "Folder"
        case .package: "Package"
        case .file: node.category == .other ? "File" : node.category.title
        case .symlink: "Alias"
        case .smallFiles: "Smaller files"
        case .special: "Special file"
        case .system: "macOS"
        case .unaccounted: "Other space"
        }
    }

    private static func displayName(of index: Int32, in tree: ScanTree) -> String {
        let node = tree[index]
        return node.kind == .smallFiles ? "\(node.fileCount) smaller files" : tree.name(of: index)
    }
}
