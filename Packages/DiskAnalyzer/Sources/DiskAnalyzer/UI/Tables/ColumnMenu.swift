import AppKit

/// The header's context menu, as in Finder: a check for each column but the name, to show or hide it. Hidden columns
/// are remembered with the table's other column settings.
final class ColumnMenu: NSObject, NSMenuDelegate {
    private weak var table: NSTableView?
    let menu = NSMenu()

    init(table: NSTableView) {
        self.table = table
        super.init()
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let table else { return }
        for column in table.tableColumns where column.identifier.rawValue != "name" && !column.title.isEmpty {
            let item = NSMenuItem(title: column.title, action: #selector(toggle), keyEquivalent: "")
            item.target = self
            item.representedObject = column
            item.state = column.isHidden ? .off : .on
            menu.addItem(item)
        }
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else { return }
        column.isHidden.toggle()
        if let table {
            ColumnFitting.fit(table)
        }
    }
}
