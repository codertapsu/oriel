import AppKit

/// The Process Name column: icon, name, and a flame when the process is over a heavy-use threshold. Like
/// `MetricCell`, it draws itself rather than holding subviews.
final class ProcessNameCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ActivityMonitor.nameCell")
    static let font = NSFont.systemFont(ofSize: 12)
    static let groupFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    static let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold))

    private var name = ""
    private var image: NSImage?
    private var isGroup = false
    private var isHeavy = false
    private var isDimmed = false

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

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            if backgroundStyle != oldValue {
                needsDisplay = true
            }
        }
    }

    override func draw(_: NSRect) {
        let selected = backgroundStyle == .emphasized
        image?.draw(in: CGRect(x: 2, y: ((bounds.height - 16) / 2).rounded(), width: 16, height: 16))
        let font = isGroup ? Self.groupFont : Self.font
        let color: NSColor = selected ? .alternateSelectedControlTextColor : isDimmed ? .tertiaryLabelColor : .labelColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(string: name, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        let lineHeight = ceil(font.ascender - font.descender)
        let flameWidth: CGFloat = isHeavy ? 16 : 0
        let room = max(0, bounds.width - 23 - flameWidth - 2)
        let width = min(room, ceil(string.size().width))
        let rect = CGRect(x: 23, y: ((bounds.height - lineHeight) / 2).rounded(), width: width, height: lineHeight)
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        if isHeavy, let flame = Self.flame {
            let tint = selected ? NSColor.alternateSelectedControlTextColor : ActivityColors.heavy
            let tinted = flame.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tint])) ?? flame
            let size = tinted.size
            tinted.draw(in: CGRect(
                x: rect.maxX + 3,
                y: ((bounds.height - size.height) / 2).rounded(),
                width: size.width,
                height: size.height
            ))
        }
    }

    func configure(_ process: ProcessMetrics, icon: NSImage, isGroup: Bool, heavyNote: String?) {
        let dimmed = process.status == .zombie
        if process.name != name || icon !== image || isGroup != self.isGroup || (heavyNote != nil) != isHeavy || dimmed != isDimmed {
            name = process.name
            image = icon
            self.isGroup = isGroup
            isHeavy = heavyNote != nil
            isDimmed = dimmed
            needsDisplay = true
        }
        let lines = [process.path, heavyNote.map { "Heavy use: \($0)" }].compactMap(\.self)
        let tip = lines.isEmpty ? nil : lines.joined(separator: "\n")
        if toolTip != tip {
            toolTip = tip
        }
        let suffix = heavyNote.map { ", \($0)" } ?? ""
        setAccessibilityValue("\(process.name)\(isGroup ? ", app with helpers" : "")\(suffix)")
    }
}
