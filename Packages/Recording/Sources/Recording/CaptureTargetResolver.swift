import AppKit
import CoreGraphics
import OrielCore
import ScreenCaptureKit
import SharedUI

/// Finds a target's display and the pixels to record in the current shareable content.
enum CaptureTargetResolver {
    /// The display that shows the target and the recorded area on it.
    static func resolve(
        _ target: RecordingTarget,
        in content: SCShareableContent
    ) throws -> (display: SCDisplay, geometry: CaptureGeometry) {
        let display: SCDisplay
        let area: CGRect?
        switch target {
        case let .display(id):
            display = try find(id, in: content)
            area = nil
        case let .region(rect, id):
            display = try find(id, in: content)
            area = rect.standardized
        case let .window(id):
            guard let window = content.windows.first(where: { $0.windowID == id }) else {
                throw RecordingError.windowNotFound
            }
            let displays = content.displays
            guard let index = ScreenGeometry.bestDisplay(for: window.frame, among: displays.map(\.frame)) else {
                throw RecordingError.displayNotFound
            }
            display = displays[index]
            area = window.frame
        }
        guard let geometry = CaptureGeometry(area: area, displayFrame: display.frame, scale: scale(of: display.displayID)) else {
            throw RecordingError.emptyArea
        }
        return (display, geometry)
    }

    /// The display with `id` in `content`.
    static func find(_ id: CGDirectDisplayID, in content: SCShareableContent) throws -> SCDisplay {
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw RecordingError.displayNotFound
        }
        return display
    }

    /// Pixels per point of a display: its screen's backing scale, else its display mode, else 1.
    static func scale(of displayID: CGDirectDisplayID) -> CGFloat {
        if let screen = ScreenLocator.screen(for: displayID) {
            return screen.backingScaleFactor
        }
        if let mode = CGDisplayCopyDisplayMode(displayID), mode.width > 0 {
            return CGFloat(mode.pixelWidth) / CGFloat(mode.width)
        }
        return 1
    }
}
