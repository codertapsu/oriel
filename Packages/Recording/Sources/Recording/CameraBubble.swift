import AppKit
import AVFoundation
import SharedUI

/// The camera bubble (PLAN §7.4): a round floating panel showing the camera through `AVCaptureVideoPreviewLayer`.
/// It is an ordinary window on screen, so the recording picks it up. The user can drag it anywhere.
final class CameraBubble {
    private let panel: FloatingPanel
    private let camera = CameraCaptureSession()
    private let preview: CameraPreviewView

    /// nil when the Mac has no camera or it cannot be opened. `frame` is in Cocoa screen coordinates.
    init?(frame: CGRect) {
        guard let device = AVCaptureDevice.systemPreferredCamera ?? AVCaptureDevice.default(for: .video) else {
            return nil
        }
        do {
            try camera.configure(device: device)
        } catch {
            return nil
        }
        panel = FloatingPanel(contentRect: frame, level: .statusBar)
        panel.isMovableByWindowBackground = true
        preview = CameraPreviewView(session: camera.session)
        panel.contentView = preview
        panel.setFrame(frame, display: false)
        preview.mirror()
    }

    func show() {
        camera.start()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        camera.stop()
    }
}
