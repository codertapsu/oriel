import AppKit
import SharedUI

/// The displays right now, from `NSScreen`, which is main-thread only: read on the main actor at each action (it costs
/// nothing) and handed to the AX actor as values, so a display arranged or unplugged a moment ago is already known.
enum DisplayReader {
    static func current() -> [DisplayGeometry] {
        let screens = NSScreen.screens
        // The first screen is the primary display, whose bottom-left corner is Cocoa's origin.
        guard let primary = screens.first else { return [] }
        return screens.map { screen in
            DisplayGeometry(
                id: ScreenLocator.displayID(of: screen) ?? 0,
                cocoaFrame: screen.frame,
                cocoaVisibleFrame: screen.visibleFrame,
                primaryHeight: primary.frame.height
            )
        }
    }
}
