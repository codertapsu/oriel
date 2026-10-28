import AppKit
import QuartzCore
import SharedUI

/// A dashed outline just outside the region of a running scrolling capture. It ignores the mouse, so scrolling and
/// clicks reach the app underneath, and it is left out of the frames like every Oriel window.
final class ScrollingRegionFrame {
    private let panel: FloatingPanel

    init(region: CGRect) {
        let frame = ScreenLocator.cocoaRect(fromCG: region).insetBy(dx: -4, dy: -4)
        panel = FloatingPanel(contentRect: frame, level: .statusBar)
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.animationBehavior = .none
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let outline = CAShapeLayer()
        outline.path = CGPath(rect: view.bounds.insetBy(dx: 1.5, dy: 1.5), transform: nil)
        outline.fillColor = nil
        outline.strokeColor = NSColor.controlAccentColor.cgColor
        outline.lineWidth = 2
        outline.lineDashPattern = [6, 4]
        view.layer?.addSublayer(outline)
        panel.contentView = view
        panel.setFrame(frame, display: false)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }
}
