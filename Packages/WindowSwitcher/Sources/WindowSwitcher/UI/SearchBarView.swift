import AppKit

/// Shows the typed search above the tiles. Typing reaches the switcher through the event tap, so this is a
/// label, not a field: the panel never has to become key.
final class SearchBarView: NSView {
    private let icon = NSImageView()
    private let queryField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        icon.contentTintColor = .secondaryLabelColor
        queryField.font = .systemFont(ofSize: 15)
        queryField.lineBreakMode = .byTruncatingHead
        countField.font = .systemFont(ofSize: 12)
        countField.textColor = .secondaryLabelColor
        countField.alignment = .right
        for view in [icon, queryField, countField] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func update(query: String, resultCount: Int) {
        queryField.stringValue = query
        countField.stringValue = resultCount == 1 ? "1 window" : "\(resultCount) windows"
        setAccessibilityLabel("Search: \(query), \(countField.stringValue)")
    }

    override func layout() {
        super.layout()
        let midY = bounds.height / 2 + 4
        icon.frame = CGRect(x: 18, y: midY - 9, width: 18, height: 18)
        countField.frame = CGRect(x: bounds.width - 110, y: midY - 8, width: 94, height: 16)
        queryField.frame = CGRect(x: 44, y: midY - 10, width: max(countField.frame.minX - 52, 0), height: 20)
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .staticText
    }
}
