import AppKit
import OrielCore

/// Window Tiling's access to Oriel's own windows, through AppKit on the main thread. Oriel never sends itself an AX
/// request: macOS answers one by running AppKit's accessibility code on the asking thread, the AX actor's, where AppKit
/// must not run (docs/os-quirks.md). Frames are in Accessibility's global coordinates, like `AXWindowAccess`'s.
struct OwnWindowAccess: @MainActor WindowAccessing {
    /// The window in front: the key window, else the main one. Tests hand in their own.
    var window: () -> NSWindow? = { NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow }
    /// The primary display's height, which turns AppKit's coordinates into Accessibility's.
    var primaryHeight: () -> CGFloat = { NSScreen.screens.first?.frame.height ?? 0 }

    func focusedWindow(of _: Int32) -> WindowLookup<NSWindow> {
        window().map { .found($0) } ?? .noWindow
    }

    func key(of window: NSWindow) -> ObjectIdentifier {
        ObjectIdentifier(window)
    }

    /// Panels count as windows: Oriel's floating panels move like any other window.
    func snapshot(of window: NSWindow) -> WindowSnapshot? {
        WindowSnapshot(
            frame: globalFrame(of: window),
            role: window.isSheet ? WindowSnapshot.sheetRole : WindowSnapshot.windowRole,
            isFullScreen: window.styleMask.contains(.fullScreen),
            isMinimized: window.isMiniaturized,
            canMove: window.isMovable,
            canResize: window.styleMask.contains(.resizable)
        )
    }

    func frame(of window: NSWindow) -> CGRect? {
        globalFrame(of: window)
    }

    /// Keeps the top left corner where it is, as setting `kAXSizeAttribute` does.
    @discardableResult
    func setSize(_ size: CGSize, of window: NSWindow) -> Bool {
        place(window, at: CGRect(origin: globalFrame(of: window).origin, size: size))
    }

    @discardableResult
    func setPosition(_ origin: CGPoint, of window: NSWindow) -> Bool {
        place(window, at: CGRect(origin: origin, size: globalFrame(of: window).size))
    }

    /// AppKit animates nothing here, so there is nothing to turn off.
    func withEnhancedUserInterfaceOff<Result>(pid _: Int32, _ body: () -> Result) -> Result {
        body()
    }

    private func globalFrame(of window: NSWindow) -> CGRect {
        ScreenGeometry.cgRect(fromCocoa: window.frame, primaryHeight: primaryHeight())
    }

    private func place(_ window: NSWindow, at frame: CGRect) -> Bool {
        window.setFrame(ScreenGeometry.cocoaRect(fromCG: frame, primaryHeight: primaryHeight()), display: true)
        return true
    }
}
