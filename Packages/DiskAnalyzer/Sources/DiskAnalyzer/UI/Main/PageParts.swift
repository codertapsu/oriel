import AppKit

/// The pieces the panes are built from, in one style: titles, wrapping text, key–value rows and button rows.
enum PageParts {
    static func title(_ text: String, size: CGFloat = 20) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: .semibold)
        field.isSelectable = false
        return field
    }

    static func heading(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return field
    }

    static func text(_ text: String, secondary: Bool = true, size: CGFloat = NSFont.systemFontSize) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size)
        field.textColor = secondary ? .secondaryLabelColor : .labelColor
        field.isSelectable = false
        return field
    }

    /// A label and its value, with an optional color swatch for a legend.
    struct Fact {
        var label: String
        var value: String
        var swatch: NSColor?

        init(_ label: String, _ value: String, swatch: NSColor? = nil) {
            self.label = label
            self.value = value
            self.swatch = swatch
        }
    }

    /// Labels and values in two aligned columns, as in Get Info.
    static func facts(_ facts: [Fact]) -> NSView {
        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.rowSpacing = 5
        grid.columnSpacing = 12
        for fact in facts {
            let name = NSTextField(labelWithString: fact.label)
            name.textColor = .secondaryLabelColor
            var label: NSView = name
            if let swatch = fact.swatch {
                let row = NSStackView(views: [SwatchView(color: swatch), name])
                row.spacing = 6
                row.alignment = .centerY
                label = row
            }
            let value = NSTextField(labelWithString: fact.value)
            value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            value.lineBreakMode = .byTruncatingMiddle
            value.isSelectable = true
            value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            grid.addRow(with: [label, value])
        }
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .leading
        grid.rowAlignment = .firstBaseline
        return grid
    }

    static func icon(_ symbol: String, size: CGFloat = 40, tint: NSColor = .controlAccentColor) -> NSImageView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .light)
        image.contentTintColor = tint
        return image
    }

    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
