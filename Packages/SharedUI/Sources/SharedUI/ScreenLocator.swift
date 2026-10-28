import AppKit
import OrielCore

/// Screens in both coordinate systems (see `ScreenGeometry`).
public enum ScreenLocator {
    /// The height of the primary display (the one with the menu bar at (0, 0)), which flips coordinates.
    public static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// The screen under the mouse pointer, else the main screen.
    public static var screenUnderMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }

    /// A screen's frame in global CoreGraphics coordinates.
    public static func cgFrame(of screen: NSScreen) -> CGRect {
        ScreenGeometry.cgRect(fromCocoa: screen.frame, primaryHeight: primaryHeight)
    }

    public static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    public static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { self.displayID(of: $0) == displayID }
    }

    /// The screen that shows most of `cgRect`.
    public static func screen(containing cgRect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        return ScreenGeometry.bestDisplay(for: cgRect, among: screens.map(cgFrame)).map { screens[$0] }
    }

    public static func cocoaRect(fromCG rect: CGRect) -> CGRect {
        ScreenGeometry.cocoaRect(fromCG: rect, primaryHeight: primaryHeight)
    }

    public static func cgRect(fromCocoa rect: CGRect) -> CGRect {
        ScreenGeometry.cgRect(fromCocoa: rect, primaryHeight: primaryHeight)
    }
}
