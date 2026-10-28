import AppKit

/// The text style of labels and step numbers, measured and drawn the same way everywhere, so the editing overlay,
/// hit-testing and the exported pixels agree.
nonisolated enum TextLayout {
    static let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    static func font(size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: max(size, 1), weight: .semibold)
    }

    static func attributes(color: RGBAColor, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: font(size: fontSize), .foregroundColor: color.nsColor]
    }

    /// The size `text` takes. An empty label (or a last empty line) still measures one line, for the caret.
    static func size(of text: String, fontSize: CGFloat) -> CGSize {
        let measured = text.isEmpty || text.hasSuffix("\n") ? text + " " : text
        let rect = (measured as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: options,
            attributes: [.font: font(size: fontSize)],
            context: nil
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    /// Draws `text` with its top-left corner at `origin` into a context whose user space has y going down.
    static func draw(_ text: String, at origin: CGPoint, color: RGBAColor, fontSize: CGFloat, in context: CGContext) {
        guard !text.isEmpty else { return }
        let rect = CGRect(origin: origin, size: size(of: text, fontSize: fontSize))
        withFlippedGraphicsContext(context) {
            (text as NSString).draw(with: rect, options: options, attributes: attributes(color: color, fontSize: fontSize), context: nil)
        }
    }

    /// Draws `text` centred on `center` (step numbers).
    static func draw(_ text: String, centeredOn center: CGPoint, color: RGBAColor, fontSize: CGFloat, in context: CGContext) {
        let size = size(of: text, fontSize: fontSize)
        draw(text, at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), color: color, fontSize: fontSize, in: context)
    }

    /// AppKit string drawing needs a current NSGraphicsContext; this one wraps `context` and says it is flipped.
    private static func withFlippedGraphicsContext(_ context: CGContext, _ body: () -> Void) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        body()
        NSGraphicsContext.current = previous
    }
}
