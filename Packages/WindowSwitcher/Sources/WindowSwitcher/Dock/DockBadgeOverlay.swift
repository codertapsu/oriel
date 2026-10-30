import AppKit
import SharedUI

/// The window counts on Dock icons (PLAN §7.1.12): one transparent window over the Dock's list, just above the Dock's
/// level, that the mouse goes through, with a capsule on each icon whose app has two windows or more. No app can set
/// another app's Dock badge: the Dock's `AXStatusLabel` cannot be set, and LaunchServices lets an app change another's
/// only with a private entitlement. The window is on every Space but not on full-screen ones, where the Dock hides, it
/// stays put in Mission Control, and Oriel's captures leave it out like all of Oriel's windows.
final class DockBadgeOverlay {
    /// A count and the frame of the icon it goes on (CoreGraphics coordinates).
    struct Badge: Equatable {
        var text: String
        var itemFrame: CGRect
    }

    private let window: NSPanel
    private var views: [DockBadgeView] = []
    private(set) var isVisible = false

    init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        let content = NSView()
        content.setAccessibilityElement(false)
        window.contentView = content
    }

    /// Puts `badges` on the icons of a Dock on `edge`; hides the window when there are none.
    func show(_ badges: [Badge], edge: DockLayout.Edge) {
        let display = AccessibilityDisplay.current
        let frames = badges.map { badge in
            let height = DockBadgeLayout.height(forIcon: DockBadgeLayout.iconRect(of: badge.itemFrame).height)
            return DockBadgeLayout.frame(
                itemFrame: badge.itemFrame, edge: edge, textWidth: DockBadgeView.textWidth(badge.text, height: height)
            )
        }
        guard let first = frames.first, let content = window.contentView else {
            hide()
            return
        }
        let area = frames.dropFirst().reduce(first) { $0.union($1) }
        window.setFrame(ScreenLocator.cocoaRect(fromCG: area), display: false)
        while views.count < badges.count {
            let view = DockBadgeView()
            content.addSubview(view)
            views.append(view)
        }
        while views.count > badges.count {
            views.removeLast().removeFromSuperview()
        }
        for (index, view) in views.enumerated() {
            let frame = frames[index]
            // The content view is not flipped: y goes up from the window's bottom.
            view.frame = CGRect(x: frame.minX - area.minX, y: area.maxY - frame.maxY, width: frame.width, height: frame.height)
            view.text = badges[index].text
            view.display = display
        }
        if !isVisible {
            window.orderFrontRegardless()
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        window.orderOut(nil)
        isVisible = false
    }
}
