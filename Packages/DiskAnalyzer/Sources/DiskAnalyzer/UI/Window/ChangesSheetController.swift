import AppKit

/// What grew since the previous scan of the same folder: the folders whose size changed the most, each shown at the
/// level that explains the change.
final class ChangesSheetController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let panel = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 620, height: 440),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: true
    )
    private let diff: SnapshotDiff
    private let table = NSTableView()

    init(diff: SnapshotDiff, rootName: String) {
        self.diff = diff
        super.init()
        let title = NSTextField(labelWithString: "Changes since \(DiskFormat.date(diff.since))")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        let summary = NSTextField(wrappingLabelWithString: """
        \(rootName): \(DiskFormat.change(diff.totalDelta)), from \(DiskFormat.bytes(diff.totalBefore)) to \
        \(DiskFormat.bytes(diff.totalAfter)). Changes of less than 50 MB are left out.
        """)
        summary.textColor = .secondaryLabelColor
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        setUpTable()
        let done = NSButton(title: "Done", target: self, action: #selector(close))
        done.keyEquivalent = "\r"
        let stack = NSStackView(views: [title, summary, scroll, done])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            summary.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            done.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -20),
        ])
        panel.contentView = content
        panel.setContentSize(CGSize(width: 620, height: 440))
    }

    private func setUpTable() {
        for (id, title, width) in [
            ("folder", "Folder", 300.0),
            ("before", "Before", 90.0),
            ("after", "Now", 90.0),
            ("delta", "Change", 90.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            if id != "folder" {
                column.headerCell.alignment = .right
            }
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.style = .inset
        table.setAccessibilityLabel("Changes")
    }

    func numberOfRows(in _: NSTableView) -> Int {
        max(1, diff.changes.count)
    }

    func tableView(_: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let column else { return nil }
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingMiddle
        guard diff.changes.indices.contains(row) else {
            field.stringValue = column.identifier.rawValue == "folder" ? "No folder changed by 50 MB or more." : ""
            field.textColor = .secondaryLabelColor
            return field
        }
        let change = diff.changes[row]
        switch column.identifier.rawValue {
        case "folder": field.stringValue = change.path
        case "before": field.stringValue = change.before.map(DiskFormat.bytes) ?? "new"
        case "after": field.stringValue = change.after.map(DiskFormat.bytes) ?? "gone"
        default:
            field.stringValue = DiskFormat.change(change.delta)
            field.textColor = change.delta > 0 ? .systemOrange : .systemGreen
        }
        if column.identifier.rawValue != "folder" {
            field.alignment = .right
            field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        return field
    }

    @objc private func close() {
        panel.sheetParent?.endSheet(panel)
    }
}
