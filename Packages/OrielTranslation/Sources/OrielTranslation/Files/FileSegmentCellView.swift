import AppKit

/// One side of a row in the file window: a caption (a cue's timing) above the text. Row heights are measured by
/// `FileSegmentTable` with the same fonts and insets, so the text never clips.
@MainActor
final class FileSegmentCellView: NSTableCellView {
    static let insets = NSEdgeInsets(top: 7, left: 6, bottom: 7, right: 6)
    static let captionSpacing: CGFloat = 2
    /// NSTextField draws wrapped text this far in from its edges.
    static let textPadding: CGFloat = 2

    private let caption = NSTextField(labelWithString: "")
    private let body = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(frame: .zero)
        caption.font = Self.captionFont
        caption.textColor = .secondaryLabelColor
        caption.lineBreakMode = .byTruncatingTail
        body.isSelectable = false
        body.lineBreakMode = .byWordWrapping
        body.cell?.wraps = true
        body.cell?.truncatesLastVisibleLine = false
        addSubview(caption)
        addSubview(body)
        textField = body
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static let captionFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

    /// `captionSpace` keeps the translation's first line level with the original's when only the original has a
    /// caption.
    func show(text: String, font: NSFont, color: NSColor, caption captionText: String?, captionSpace: Bool) {
        caption.stringValue = captionText ?? ""
        caption.isHidden = captionText == nil
        reservesCaptionSpace = captionSpace
        body.stringValue = text
        body.font = font
        body.textColor = color
        setAccessibilityLabel(text)
        needsLayout = true
    }

    private var reservesCaptionSpace = false

    override func layout() {
        super.layout()
        let insets = Self.insets
        var top = insets.top
        let width = max(0, bounds.width - insets.left - insets.right)
        if !caption.isHidden || reservesCaptionSpace {
            let height = Self.captionHeight
            caption.frame = CGRect(x: insets.left, y: bounds.height - top - height, width: width, height: height)
            top += height + Self.captionSpacing
        }
        let bodyHeight = max(0, bounds.height - top - insets.bottom)
        body.frame = CGRect(x: insets.left, y: insets.bottom, width: width, height: bodyHeight)
    }

    static var captionHeight: CGFloat {
        ceil(captionFont.ascender - captionFont.descender + captionFont.leading)
    }

    /// The height the text needs at `width` (the column's width), as the cell lays it out.
    static func textHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let available = max(1, width - insets.left - insets.right - 2 * textPadding)
        let string = NSAttributedString(string: text.isEmpty ? " " : text, attributes: [.font: font])
        let rect = string.boundingRect(
            with: CGSize(width: available, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height) + 2
    }
}
