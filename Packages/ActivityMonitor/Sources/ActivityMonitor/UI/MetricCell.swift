import AppKit

/// Every column but the name: numbers right-aligned in monospaced digits, words left-aligned. A value over its
/// heavy-use threshold is orange; a stand-in value (another user's real memory under Memory) is dimmed, and a value of
/// nothing lighter still.
///
/// It draws its text itself instead of holding a text field: a list redraws a few hundred of these every sample, and
/// AppKit's work per subview (layout, the key-view loop) cost more than the drawing.
final class MetricCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ActivityMonitor.metricCell")
    static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    static let heavyFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    static let textFont = NSFont.systemFont(ofSize: 12)

    private var text = ""
    private var font = MetricCell.numberFont
    private var color = NSColor.labelColor
    private var alignment = NSTextAlignment.right

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The selected row's colours.
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            if backgroundStyle != oldValue {
                needsDisplay = true
            }
        }
    }

    override func draw(_: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let foreground = backgroundStyle == .emphasized ? NSColor.alternateSelectedControlTextColor : color
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: foreground, .paragraphStyle: paragraph])
        let lineHeight = ceil(font.ascender - font.descender)
        let rect = CGRect(x: 2, y: ((bounds.height - lineHeight) / 2).rounded(), width: max(0, bounds.width - 6), height: lineHeight)
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    /// `quiet` draws a value of nothing (or a dash) in a lighter colour.
    func configure(_ text: String, numeric: Bool, heavy: Bool, quiet: Bool, standIn: Bool, toolTip: String?) {
        let font = numeric ? (heavy ? Self.heavyFont : Self.numberFont) : Self.textFont
        let color: NSColor = if heavy {
            ActivityColors.heavy
        } else if quiet || text == ActivityFormat.dash {
            .tertiaryLabelColor
        } else if standIn {
            .secondaryLabelColor
        } else {
            .labelColor
        }
        let alignment: NSTextAlignment = numeric ? .right : .left
        if text != self.text || font != self.font || color != self.color || alignment != self.alignment {
            self.text = text
            self.font = font
            self.color = color
            self.alignment = alignment
            needsDisplay = true
            setAccessibilityValue(text)
        }
        if self.toolTip != toolTip {
            self.toolTip = toolTip
        }
    }
}
