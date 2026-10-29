import AppKit
import SharedUI

/// A card in the middle of a display that says why something cannot work and which keys help: in Dimensions without
/// Screen Recording, or after the screen could not be read.
final class RulerNoticeView: NSView {
    static let width: CGFloat = 400

    private let background = Material.make(cornerRadius: 18)
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let keys = NSStackView()
    private var shown: RulerNotice?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.alignment = .center
        message.font = .systemFont(ofSize: 12.5)
        message.textColor = .secondaryLabelColor
        message.alignment = .center
        message.preferredMaxLayoutWidth = Self.width - 48
        keys.spacing = 18
        let stack = NSStackView(views: [icon, title, message, keys])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(14, after: message)
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ notice: RulerNotice) {
        guard notice != shown else { return }
        shown = notice
        icon.image = NSImage(systemSymbolName: notice.symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        title.stringValue = notice.title
        message.stringValue = notice.message
        keys.setViews(notice.keys.map(KeyCapView.init), in: .center)
        layoutSubtreeIfNeeded()
        setFrameSize(fittingSize)
        setAccessibilityLabel("\(notice.title). \(notice.message)")
    }
}
