import AppKit

/// Buttons in a row that wraps onto more lines when the pane is too narrow for them, so none is ever cut off.
final class ButtonRow: NSView {
    private var buttons: [NSButton] = []
    private var handlers: [() -> Void] = []
    private let spacing: CGFloat = 8
    private var laidOutHeight: CGFloat = 0

    init(_ entries: [(title: String, action: () -> Void)], primaryFirst: Bool = true) {
        super.init(frame: .zero)
        for (index, entry) in entries.enumerated() {
            let button = NSButton(title: entry.title, target: self, action: #selector(pressed))
            button.tag = index
            button.bezelStyle = .push
            if index == 0, primaryFirst {
                button.keyEquivalent = "\r"
            }
            handlers.append(entry.action)
            buttons.append(button)
            addSubview(button)
        }
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: max(laidOutHeight, buttons.first?.intrinsicContentSize.height ?? 0))
    }

    override func layout() {
        super.layout()
        let height = place(in: bounds.width)
        if height != laidOutHeight {
            laidOutHeight = height
            invalidateIntrinsicContentSize()
        }
    }

    /// Lays the buttons out left to right, starting a new line where one would not fit; returns the height used.
    private func place(in width: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for button in buttons {
            let size = button.intrinsicContentSize
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            button.frame = CGRect(x: x, y: y, width: min(size.width, width), height: size.height)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return y + lineHeight
    }

    @objc private func pressed(_ sender: NSButton) {
        guard handlers.indices.contains(sender.tag) else { return }
        handlers[sender.tag]()
    }
}
