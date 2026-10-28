import AppKit
import SharedUI

/// The full-size preview (PLAN §1.2, §7.1.10): a borderless panel at `.popUpMenu - 1`, just under the
/// switcher and above every app, showing the selected window's capture at the window's real frame. A cached
/// thumbnail stands in, dimmed, until the full-resolution capture arrives; minimized windows, which cannot be
/// captured, stay dimmed.
final class PreviewPanelController {
    private let panel = FloatingPanel(level: NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1))
    private let imageView = ThumbnailView()
    private(set) var windowID: UInt32?

    init() {
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        imageView.cornerRadius = 12
        panel.contentView = imageView
        panel.setAccessibilityElement(false)
    }

    /// `frame` is the window's frame in global CoreGraphics coordinates.
    func show(_ image: CGImage, windowID: UInt32, frame: CGRect, isStale: Bool) {
        let cocoa = ScreenLocator.cocoaRect(fromCG: frame)
        guard frame.width > 1, frame.height > 1, NSScreen.screens.contains(where: { $0.frame.intersects(cocoa) }) else {
            hide()
            return
        }
        self.windowID = windowID
        imageView.image = image
        imageView.isDimmed = isStale
        panel.animationBehavior = .none
        panel.setFrame(cocoa, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        imageView.image = nil
        windowID = nil
    }
}
