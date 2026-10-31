import AppKit
import OrielCore
import SharedUI

/// Oriel's own windows, read and handled through AppKit on the main thread (PLAN §7.1.1). The switcher never sends an
/// AX request to its own process (`AXClient.ownPID`), so Settings, the editor and the tools' windows are listed,
/// focused, closed and minimized here. Only standard windows count (`StandardWindows`), so the switcher's own panel, the
/// capture overlays, pins and floating panels never appear.
enum OwnWindows {
    /// The windows that count, as the AX actor would describe them.
    static func records() -> [AXWindowRecord] {
        let app = NSApplication.shared
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return app.windows.filter(isListed).map { window in
            AXWindowRecord(
                windowID: UInt32(window.windowNumber),
                title: window.title,
                frame: ScreenGeometry.cgRect(fromCocoa: window.frame, primaryHeight: primaryHeight),
                isMinimized: window.isMiniaturized,
                isFullScreen: window.styleMask.contains(.fullScreen)
            )
        }
    }

    /// The key window, else the main one, when it counts.
    static var focusedWindowID: UInt32? {
        let app = NSApplication.shared
        guard let window = app.keyWindow ?? app.mainWindow, isListed(window) else { return nil }
        return UInt32(window.windowNumber)
    }

    /// Brings the window front and key, out of the Dock if it was minimized.
    static func focus(_ id: UInt32) -> Bool {
        guard let window = window(id) else { return false }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        return true
    }

    static func perform(_ action: WindowAction, on id: UInt32) -> Bool {
        guard let window = window(id) else { return false }
        switch action {
        case .close: window.performClose(nil)
        case .minimize: window.miniaturize(nil)
        case .toggleFullScreen: window.toggleFullScreen(nil)
        }
        return true
    }

    static func setMinimized(_ minimized: Bool, id: UInt32) -> Bool {
        guard let window = window(id) else { return false }
        if minimized {
            window.miniaturize(nil)
        } else {
            window.deminiaturize(nil)
        }
        return true
    }

    private static func isListed(_ window: NSWindow) -> Bool {
        StandardWindows.isOpen(window)
    }

    private static func window(_ id: UInt32) -> NSWindow? {
        guard let window = NSApplication.shared.window(withWindowNumber: Int(id)), isListed(window) else { return nil }
        return window
    }
}
