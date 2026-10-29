import AppKit

/// Keeps a table's columns inside its pane: when they add up to more than the visible width (the first time a table
/// shows, or a pane got narrower), they share it out again. Widths the user set that fit are left alone.
enum ColumnFitting {
    static func fit(_ table: NSTableView) {
        guard let visible = table.enclosingScrollView?.contentSize.width, visible > 100 else { return }
        let total = table.tableColumns.filter { !$0.isHidden }.reduce(CGFloat(0)) { $0 + $1.width }
            + table.intercellSpacing.width * CGFloat(table.tableColumns.count)
        guard total > visible + 1 else { return }
        table.sizeToFit()
    }
}
