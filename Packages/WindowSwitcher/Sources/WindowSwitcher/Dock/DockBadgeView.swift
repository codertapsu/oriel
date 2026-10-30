import AppKit
import SharedUI

/// One window count on a Dock icon: white digits on a dark capsule with a light outline, readable on light and dark icons
/// alike and unlike the red badges apps show. Drawn only; VoiceOver reads the Dock itself.
final class DockBadgeView: NSView {
    var text = "" {
        didSet { needsDisplay = true }
    }

    var display = AccessibilityDisplay.current {
        didSet { needsDisplay = true }
    }

    static func font(forHeight height: CGFloat) -> NSFont {
        .monospacedDigitSystemFont(ofSize: (height * 0.68).rounded(), weight: .semibold)
    }

    /// The width of `text` in a capsule of `height` points, which `DockBadgeLayout` sizes the capsule by.
    static func textWidth(_ text: String, height: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font(forHeight: height)]).width
    }

    override func draw(_: NSRect) {
        let rect = bounds.insetBy(dx: 0.75, dy: 0.75)
        let capsule = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor(white: 0.12, alpha: display.reduceTransparency ? 1 : 0.9).setFill()
        capsule.fill()
        NSColor(white: 1, alpha: display.increaseContrast ? 1 : 0.6).setStroke()
        capsule.lineWidth = display.increaseContrast ? 1.5 : 1
        capsule.stroke()
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font(forHeight: bounds.height), .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: CGPoint(x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded()),
            withAttributes: attributes
        )
    }

    override func isAccessibilityElement() -> Bool {
        false
    }
}
