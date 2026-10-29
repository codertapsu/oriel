import AppKit

/// A titled group of label–value rows in the details pane. Values wrap and can be selected and copied.
final class DetailSection: NSView {
    private let title = NSTextField(labelWithString: "")
    private let grid = NSGridView()
    private var values: [String: NSTextField] = [:]
    /// Wrapping width for the values, set from the pane's width.
    var valueWidth: CGFloat = 170 {
        didSet {
            for field in values.values {
                field.preferredMaxLayoutWidth = valueWidth
            }
        }
    }

    init(_ text: String) {
        super.init(frame: .zero)
        title.stringValue = text.uppercased()
        title.font = .systemFont(ofSize: 10, weight: .semibold)
        title.textColor = .secondaryLabelColor
        grid.rowSpacing = 4
        grid.columnSpacing = 8
        let stack = NSStackView(views: [title, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Replaces the rows. A value of nil leaves its row out.
    func show(_ rows: [(title: String, value: String?)]) {
        // Removing a row leaves its views in the grid, so they go first.
        for row in (0 ..< grid.numberOfRows).reversed() {
            for column in 0 ..< grid.numberOfColumns {
                grid.cell(atColumnIndex: column, rowIndex: row).contentView?.removeFromSuperview()
            }
            grid.removeRow(at: row)
        }
        values = [:]
        for row in rows {
            guard let value = row.value else { continue }
            add(row.title, view: valueField(value, key: row.title))
        }
    }

    /// Updates one value in place, for the numbers that change with every sample.
    func set(_ title: String, _ value: String) {
        values[title]?.stringValue = value
    }

    /// A row whose value is a control, such as the parent process's link.
    func add(_ title: String, view: NSView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        let row = grid.addRow(with: [label, view])
        row.rowAlignment = .firstBaseline
        grid.column(at: 0).width = 84
        grid.column(at: 0).xPlacement = .trailing
    }

    private func valueField(_ text: String, key: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.isSelectable = true
        field.preferredMaxLayoutWidth = valueWidth
        field.setAccessibilityLabel(key)
        values[key] = field
        return field
    }
}
