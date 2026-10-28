import AppKit
import OrielCore
import os

/// The on-screen extras a recording shows and records: the camera bubble, click rings and the keystroke HUD
/// (PLAN §7.4). They are ordinary windows, so the stream's filter, which excludes only the control bar, keeps them.
final class RecordingOverlays {
    private var camera: CameraBubble?
    private var clicks: ClickRingOverlay?
    private var keys: KeystrokeHUD?
    private let log = Log.logger("recording")

    /// Shows what `features` asks for around `captureRect` (Cocoa screen coordinates) on `screen`. Clicks on
    /// `unrecordedWindows` (the control bar) get no click ring, since the video does not show them.
    func show(
        _ features: RecordingFeatures,
        captureRect: CGRect,
        on screen: NSScreen?,
        unrecordedWindows: Set<CGWindowID> = []
    ) {
        // The bubble and the HUD stay clear of the Dock and the menu bar when the area reaches under them.
        let visible = screen.map { captureRect.intersection($0.visibleFrame) } ?? captureRect
        let placement = visible.isEmpty ? captureRect : visible
        if features.cameraBubble {
            if let bubble = CameraBubble(frame: OverlayLayout.cameraBubbleFrame(captureRect: placement)) {
                bubble.show()
                camera = bubble
            } else {
                log.notice("no camera for the camera bubble")
            }
        }
        if features.clickRings {
            var area = captureRect.insetBy(dx: -ClickRingView.radius, dy: -ClickRingView.radius)
            if let screen {
                area = area.intersection(screen.frame)
            }
            let overlay = ClickRingOverlay(frame: area, ignoring: unrecordedWindows)
            overlay.start()
            clicks = overlay
        }
        if features.keystrokes {
            let hud = KeystrokeHUD(captureRect: placement)
            hud.start()
            keys = hud
        }
    }

    func hide() {
        camera?.hide()
        clicks?.stop()
        keys?.stop()
        camera = nil
        clicks = nil
        keys = nil
    }
}
