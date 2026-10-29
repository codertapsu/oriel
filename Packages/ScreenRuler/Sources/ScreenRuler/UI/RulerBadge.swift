import AppKit

/// A number on the overlay: white on a dark rounded badge, readable over anything. A primary badge can carry a second,
/// quieter line. Mouse events pass through it.
final class RulerBadge: NSView {
    private let label = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let padding = CGSize(width: 7, height: 3)
    private(set) var style = RulerScene.Label.Style.primary

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.82).cgColor
        layer?.borderColor = NSColor(white: 1, alpha: 0.14).cgColor
        layer?.borderWidth = 0.5
        label.textColor = .white
        detail.textColor = NSColor(white: 1, alpha: 0.72)
        detail.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        addSubview(label)
        addSubview(detail)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Sets the text and sizes the badge to fit it.
    func show(_ text: String, detail detailText: String?, style: RulerScene.Label.Style) {
        self.style = style
        let primary = style == .primary
        label.font = .monospacedDigitSystemFont(ofSize: primary ? 12.5 : 11, weight: primary ? .semibold : .medium)
        label.stringValue = text
        detail.stringValue = detailText ?? ""
        detail.isHidden = detailText == nil
        // A little slack: a label's intrinsic width can come out a fraction short and clip the last glyph.
        let main = label.intrinsicContentSize
        let second = detailText == nil ? .zero : detail.intrinsicContentSize
        let mainWidth = ceil(main.width) + 3
        let secondWidth = ceil(second.width) + 3
        let width = max(mainWidth, secondWidth) + 2 * padding.width
        let height = ceil(main.height + (detailText == nil ? 0 : second.height)) + 2 * padding.height
        setFrameSize(CGSize(width: width, height: height))
        detail.frame = CGRect(x: padding.width, y: padding.height, width: secondWidth, height: ceil(second.height))
        label.frame = CGRect(x: padding.width, y: height - padding.height - ceil(main.height), width: mainWidth, height: ceil(main.height))
        layer?.cornerRadius = primary ? 6 : 5
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel([text, detailText].compactMap(\.self).joined(separator: ", "))
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
