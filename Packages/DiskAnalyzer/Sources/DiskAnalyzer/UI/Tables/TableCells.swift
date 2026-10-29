import AppKit

/// The cells the lists share, made once and reused by identifier.
enum TableCells {
    static let name = NSUserInterfaceItemIdentifier("NameCell")
    static let text = NSUserInterfaceItemIdentifier("TextCell")
    static let number = NSUserInterfaceItemIdentifier("NumberCell")
    static let share = NSUserInterfaceItemIdentifier("ShareCell")

    /// An icon and a name; secondary when the item is dimmed (excluded, unreadable, hidden).
    static func name(in table: NSTableView, icon: NSImage, title: String, dimmed: Bool, badge: String? = nil) -> NSTableCellView {
        let cell = table.makeView(withIdentifier: name, owner: nil) as? NSTableCellView ?? makeNameCell()
        cell.imageView?.image = icon
        cell.textField?.stringValue = badge.map { "\(title)  \($0)" } ?? title
        cell.textField?.textColor = dimmed ? .secondaryLabelColor : .labelColor
        return cell
    }

    static func text(in table: NSTableView, _ value: String, secondary: Bool = true) -> NSTableCellView {
        let cell = table.makeView(withIdentifier: text, owner: nil) as? NSTableCellView ?? makeTextCell(identifier: text, alignment: .left)
        cell.textField?.stringValue = value
        cell.textField?.textColor = secondary ? .secondaryLabelColor : .labelColor
        return cell
    }

    static func number(in table: NSTableView, _ value: String) -> NSTableCellView {
        let cell = table.makeView(withIdentifier: number, owner: nil) as? NSTableCellView ?? makeTextCell(
            identifier: number,
            alignment: .right
        )
        cell.textField?.stringValue = value
        return cell
    }

    static func share(in table: NSTableView, fraction: Double, text value: String, tint: NSColor = .controlAccentColor) -> NSTableCellView {
        let cell = table.makeView(withIdentifier: share, owner: nil) as? ShareCellView ?? ShareCellView()
        cell.identifier = share
        cell.bar.fraction = fraction
        cell.bar.tint = tint
        cell.textField?.stringValue = value
        return cell
    }

    private static func makeNameCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = name
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingMiddle
        for view in [icon, field] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }
        cell.imageView = icon
        cell.textField = field
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private static func makeTextCell(identifier: NSUserInterfaceItemIdentifier, alignment: NSTextAlignment) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let field = NSTextField(labelWithString: "")
        field.alignment = alignment
        field.lineBreakMode = .byTruncatingMiddle
        if alignment == .right {
            field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
