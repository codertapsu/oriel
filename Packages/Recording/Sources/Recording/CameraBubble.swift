import AppKit
import AVFoundation
import SharedUI

/// The camera bubble (PLAN §7.4): a round floating panel showing the camera through `AVCaptureVideoPreviewLayer`.
/// It is an ordinary window on screen, so the recording picks it up. The user can drag it anywhere.
///
/// With a background effect (PLAN §17), `CameraEffectProcessor` draws over the preview: the person in front, the
/// background blurred or replaced.
final class CameraBubble {
    private let panel: FloatingPanel
    private let camera = CameraCaptureSession()
    private let preview: CameraPreviewView
    private var effect: CameraEffectProcessor?

    /// nil when the Mac has no camera or it cannot be opened. `frame` is in Cocoa screen coordinates.
    init?(frame: CGRect, background: CameraBackground = .unchanged) {
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
        if background != .unchanged {
            let scale = NSScreen.screens.first { $0.frame.intersects(frame) }?.backingScaleFactor ?? 2
            let processor = CameraEffectProcessor(
                device: device,
                background: background,
                outputSize: CGSize(width: frame.width * scale, height: frame.height * scale)
            ) { [weak preview] picture in
                preview?.showEffect(picture)
            } onStop: { [camera] processor in
                // Stopped for good: the output leaves the session, so the camera does no extra work.
                camera.detach(processor.output)
            }
            if camera.attach(processor.output) {
                effect = processor
            }
        }
    }

    func show() {
        camera.start()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        camera.stop()
        effect = nil
    }
}
