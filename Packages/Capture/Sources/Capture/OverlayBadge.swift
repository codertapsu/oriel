import AppKit

/// A small dark label on the overlay: the W × H readout or the line of help. Mouse events pass through it.
final class OverlayBadge: NSView {
    private let label = NSTextField(labelWithString: "")
    private let padding = CGSize(width: 8, height: 4)

    init(fontSize: CGFloat, monospacedDigits: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.72).cgColor
        layer?.cornerRadius = 6
        label.font = monospacedDigits
            ? .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
            : .systemFont(ofSize: fontSize, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Sets the text and resizes the badge to fit it; nil hides the badge.
    var text: String? {
        get { isHidden ? nil : label.stringValue }
        set {
            guard let newValue, !newValue.isEmpty else {
                isHidden = true
                return
            }
            if label.stringValue != newValue {
                label.stringValue = newValue
                let size = label.intrinsicContentSize
                setFrameSize(CGSize(width: ceil(size.width) + 2 * padding.width, height: ceil(size.height) + 2 * padding.height))
                label.frame = CGRect(x: padding.width, y: padding.height, width: ceil(size.width), height: ceil(size.height))
            }
            isHidden = false
        }
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
