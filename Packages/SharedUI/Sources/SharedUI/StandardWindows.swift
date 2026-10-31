import AppKit

/// Oriel's standard windows: titled, at the normal level and not panels, such as Settings, the editor and the tools'
/// windows. They are the windows the switcher and the Dock preview list for Oriel (PLAN §7.1.1) and the ones that put
/// Oriel in the Dock (PLAN §10.1); capture overlays, pins, toasts and floating panels are not.
public enum StandardWindows {
    /// A standard window, whether or not it is on screen now.
    public static func isStandard(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.styleMask.contains(.titled) && window.level == .normal
    }

    /// A standard window that is open: shown, on any Space, or minimized.
    public static func isOpen(_ window: NSWindow) -> Bool {
        window.windowNumber > 0 && isStandard(window) && (window.isVisible || window.isMiniaturized)
    }

    /// Oriel's open standard windows.
    public static var open: [NSWindow] {
        NSApplication.shared.windows.filter(isOpen)
    }
}
