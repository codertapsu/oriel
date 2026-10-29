import AppKit
import SharedUI

/// The bar of keys at the bottom of the display the pointer is on: the mode, what to do in it, and its keys. After a
/// copy it says what was copied for a moment.
final class RulerHintBar: NSView {
    private let background = Material.make(cornerRadius: 12)
    private let stack = NSStackView()
    private let modeLabel = NSTextField(labelWithString: "")
    private let instruction = NSTextField(labelWithString: "")
    private var shown: (mode: String, instruction: String, keys: [KeyHint])?
    private var flashing: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        modeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        modeLabel.textColor = .labelColor
        instruction.font = .systemFont(ofSize: 12)
        instruction.textColor = .secondaryLabelColor
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
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
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Screen Ruler keys")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Lays the bar out for a mode, and sizes it to fit; unchanged content is left alone.
    func show(mode: String, instruction text: String, keys: [KeyHint]) {
        if let shown, shown.mode == mode, shown.instruction == text, shown.keys == keys {
            return
        }
        shown = (mode, text, keys)
        flashing = nil
        modeLabel.stringValue = mode
        instruction.stringValue = text
        let divider = NSBox()
        divider.boxType = .separator
        stack.setViews([modeLabel, instruction, divider] + keys.map(KeyCapView.init), in: .leading)
        divider.heightAnchor.constraint(equalToConstant: 16).isActive = true
        fit()
    }

    /// One line in place of the keys, such as "Copied 320 × 240 pt"; `show` brings the keys back.
    func flash(_ text: String, symbol: String) {
        guard text != flashing else { return }
        shown = nil
        flashing = text
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .controlAccentColor
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        label.textColor = .labelColor
        stack.setViews([icon, label], in: .leading)
        fit()
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [.announcement: text])
    }

    private func fit() {
        layoutSubtreeIfNeeded()
        setFrameSize(stack.fittingSize)
    }
}
