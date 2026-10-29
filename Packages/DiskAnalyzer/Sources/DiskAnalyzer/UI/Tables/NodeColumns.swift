import AppKit

/// The columns the lists use, with their titles, widths and sort keys.
enum NodeColumns {
    struct Spec {
        var id: String
        var title: String
        var width: CGFloat
        var key: FileSort.Key?
        var alignment: NSTextAlignment = .left
        /// Narrower than this, sizes and dates would be cut.
        var minimumWidth: CGFloat = 50
    }

    static let name = Spec(id: "name", title: "Name", width: 230, key: .name, minimumWidth: 140)
    static let size = Spec(id: "size", title: "Size", width: 76, key: .size, alignment: .right, minimumWidth: 72)
    static let share = Spec(id: "share", title: "Share", width: 100, key: .share, minimumWidth: 90)
    static let files = Spec(id: "files", title: "Files", width: 66, key: .items, alignment: .right, minimumWidth: 58)
    static let kind = Spec(id: "kind", title: "Kind", width: 96, key: .kind, minimumWidth: 84)
    static let modified = Spec(id: "modified", title: "Modified", width: 124, key: .modified, minimumWidth: 118)
    static let accessed = Spec(id: "accessed", title: "Last Accessed", width: 124, key: .accessed, minimumWidth: 118)
    static let created = Spec(id: "created", title: "Created", width: 124, key: .created, minimumWidth: 118)
    static let opened = Spec(id: "opened", title: "Last Used", width: 110, key: .lastOpened, minimumWidth: 92)
    static let folder = Spec(id: "folder", title: "Folder", width: 200, key: .folder, minimumWidth: 120)

    /// Adds the columns, which then share out the table's width as the window is resized, so none runs off the edge.
    static func add(_ specs: [Spec], to table: NSTableView) {
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        for spec in specs {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id))
            column.title = spec.title
            column.width = spec.width
            column.minWidth = min(spec.width, spec.minimumWidth)
            column.headerCell.alignment = spec.alignment
            if let key = spec.key {
                // Sizes and dates start largest and newest first; names from A.
                column.sortDescriptorPrototype = NSSortDescriptor(key: key.rawValue, ascending: key == .name || key == .folder)
            }
            column.resizingMask = [.autoresizingMask, .userResizingMask]
            table.addTableColumn(column)
        }
    }

    static func sort(from descriptors: [NSSortDescriptor]) -> FileSort? {
        guard let first = descriptors.first, let key = first.key.flatMap(FileSort.Key.init(rawValue:)) else { return nil }
        return FileSort(key: key, ascending: first.ascending)
    }

    /// "Folder", "Package", "Videos"…
    static func kind(of node: ScanNode) -> String {
        switch node.kind {
        case .folder: "Folder"
        case .package: node.category == .other ? "Package" : node.category.title
        case .file: node.category.title
        case .symlink: "Alias"
        case .smallFiles: "Smaller files"
        case .special: "Special file"
        case .system: "macOS"
        case .unaccounted: "Not in files"
        }
    }

    /// Marks after a name: cloud only, unreadable, excluded…
    static func badge(of node: ScanNode) -> String? {
        let flags = node.flags
        if flags.contains(.unreadable) {
            return "· can't be read"
        }
        if flags.contains(.cloudOnly) {
            return "· in the cloud"
        }
        if flags.contains(.excluded) {
            return "· excluded"
        }
        if flags.contains(.mountPoint) {
            return "· another volume"
        }
        if flags.contains(.firmlink) {
            return "· counted elsewhere"
        }
        return nil
    }
}
