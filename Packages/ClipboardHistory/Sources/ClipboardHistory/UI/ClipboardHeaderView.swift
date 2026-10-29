import AppKit

/// The heading above a section of the list: Pinned or History.
final class ClipboardHeaderView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ClipboardHeader")
    static let height: CGFloat = 26

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        textField = label
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ section: ClipboardSection) {
        label.stringValue = section.title
        setAccessibilityLabel(section.title)
    }
}
