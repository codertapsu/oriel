import AppKit
import OrielCore
import ScreenCaptureKit

/// The one `SCShareableContent` Capture works from (PLAN §7.1.7). Every fetch costs `tccd` work, so it is fetched
/// again only when it may be out of date: at the start of each interactive capture (window frames must be current for
/// hovering and snapping), and for headless captures once apps launched, quit, hid or unhid, the Space or the displays
/// changed, or Oriel's own windows changed (`invalidate()`). Observing those is event-driven; nothing polls.
final class ShareableContentCache {
    private(set) var content: SCShareableContent?
    private(set) var isStale = true
    private var observers: [NSObjectProtocol] = []

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        for name in names {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.invalidate() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        })
    }

    /// Marks the content out of date, e.g. after a Quick Access card or a pin appeared or closed.
    func invalidate() {
        isStale = true
    }

    /// The cached content, fetched again first when it is stale or `refresh` is true. It lists the desktop's windows
    /// too, so that the desktop icons and widgets can be left out of a capture (`desktopClutter(in:)`); window mode
    /// never offers them, because they sit below every app window.
    func current(refresh: Bool = false) async throws -> SCShareableContent {
        if !refresh, !isStale, let content {
            return content
        }
        let fresh = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        content = fresh
        isStale = false
        return fresh
    }

    /// Oriel's own on-screen windows (Quick Access cards, pins, toasts, HUDs), which every capture leaves out. Its
    /// status item stays in: on macOS 26 that is a window of Oriel's in the menu bar (on 27 it is not, see
    /// docs/os-quirks.md), and leaving it out would cut a hole into every screenshot of the menu bar.
    static func ownWindows(in content: SCShareableContent) -> [SCWindow] {
        let pid = ProcessInfo.processInfo.processIdentifier
        let menuBarTops = Set(content.displays.map(\.frame.minY))
        return content.windows.filter { window in
            window.owningApplication?.processID == pid
                && !isStatusItem(layer: window.windowLayer, frame: window.frame, menuBarTops: menuBarTops)
        }
    }

    /// Finder's desktop-icon windows and the desktop widgets (Settings → Capture → Hide desktop icons and widgets).
    static func desktopClutter(in content: SCShareableContent) -> [SCWindow] {
        content.windows.filter { window in
            DesktopClutter.isIconOrWidget(
                bundleID: window.owningApplication?.bundleIdentifier,
                ownerName: window.owningApplication?.applicationName,
                layer: window.windowLayer
            )
        }
    }

    /// What a capture leaves out: Oriel's own windows, and the desktop icons and widgets when `hidesDesktop` is on.
    static func excludedWindows(in content: SCShareableContent, hidesDesktop: Bool) -> [SCWindow] {
        let own = ownWindows(in: content)
        return hidesDesktop ? own + desktopClutter(in: content) : own
    }

    /// A status-bar-level window no taller than a menu bar, at the top edge of a display.
    nonisolated static func isStatusItem(layer: Int, frame: CGRect, menuBarTops: Set<CGFloat>) -> Bool {
        layer == Int(CGWindowLevelForKey(.statusWindow)) && frame.height <= 50 && menuBarTops.contains(frame.minY)
    }

    /// The windows window mode can pick, front to back: other apps' visible windows at normal and floating levels.
    static func windowTargets(in content: SCShareableContent) -> [WindowTarget] {
        let pid = ProcessInfo.processInfo.processIdentifier
        let order = frontToBackWindowIDs()
        let visible = Set(order.map(\.id))
        let targets = content.windows.compactMap { window -> WindowTarget? in
            guard window.isOnScreen,
                  (0 ..< Int(CGWindowLevelForKey(.dockWindow))).contains(window.windowLayer),
                  window.owningApplication?.processID != pid,
                  window.frame.width >= 24, window.frame.height >= 24,
                  visible.isEmpty || visible.contains(window.windowID)
            else {
                return nil
            }
            return WindowTarget(
                id: window.windowID,
                frame: window.frame,
                title: window.title,
                appName: window.owningApplication?.applicationName,
                processID: window.owningApplication?.processID ?? 0
            )
        }
        return WindowTarget.sorted(targets, byFrontToBack: order.map(\.id))
    }

    /// On-screen window numbers front to back, without fully transparent windows. ScreenCaptureKit does not promise
    /// an order, and the window under the pointer has to be the frontmost one.
    private static func frontToBackWindowIDs() -> [(id: CGWindowID, alpha: Double)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let number = info[kCGWindowNumber as String] as? NSNumber else { return nil }
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return alpha > 0 ? (number.uint32Value, alpha) : nil
        }
    }
}
