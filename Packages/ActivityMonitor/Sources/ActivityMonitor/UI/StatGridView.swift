import AppKit

/// Label–value pairs for the summary under the list: secondary labels, values in monospaced digits, and a small swatch
/// for a value that has a line in the graph beside it.
final class StatGridView: NSView {
    struct Row {
        let title: String
        let value: String
        var swatch: NSColor?
        var toolTip: String?

        init(_ title: String, _ value: String, swatch: NSColor? = nil, toolTip: String? = nil) {
            self.title = title
            self.value = value
            self.swatch = swatch
            self.toolTip = toolTip
        }
    }

    private let grid = NSGridView()
    private var titleFields: [NSTextField] = []
    private var valueFields: [NSTextField] = []
    private var swatches: [Swatch] = []

    /// A small rounded square in a series' colour, drawn so it follows the appearance.
    private final class Swatch: NSView {
        var color: NSColor? {
            didSet { needsDisplay = true }
        }

        override func draw(_: NSRect) {
            guard let color else { return }
            color.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        grid.rowSpacing = 3
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            grid.topAnchor.constraint(equalTo: topAnchor),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows `rows`, reusing the fields so an update every second does not rebuild the grid.
    func show(_ rows: [Row]) {
        while titleFields.count < rows.count {
            addRow()
        }
        for index in titleFields.indices {
            let visible = index < rows.count
            grid.row(at: index).isHidden = !visible
            guard visible else { continue }
            let row = rows[index]
            // Unchanged text is left alone, so a sample that changes nothing lays nothing out.
            if titleFields[index].stringValue != row.title {
                titleFields[index].stringValue = row.title
                valueFields[index].setAccessibilityLabel(row.title)
            }
            if valueFields[index].stringValue != row.value {
                valueFields[index].stringValue = row.value
            }
            if valueFields[index].toolTip != row.toolTip {
                valueFields[index].toolTip = row.toolTip
            }
            if swatches[index].color != row.swatch {
                swatches[index].color = row.swatch
            }
            swatches[index].isHidden = row.swatch == nil
        }
    }

    private func addRow() {
        let swatch = Swatch()
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 8),
            swatch.heightAnchor.constraint(equalToConstant: 8),
        ])
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 11)
        title.textColor = .secondaryLabelColor
        title.alignment = .right
        let value = NSTextField(labelWithString: "")
        value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        value.lineBreakMode = .byTruncatingTail
        value.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let row = grid.addRow(with: [title, swatch, value])
        row.yPlacement = .center
        grid.cell(for: swatch)?.xPlacement = .center
        titleFields.append(title)
        swatches.append(swatch)
        valueFields.append(value)
    }
}
