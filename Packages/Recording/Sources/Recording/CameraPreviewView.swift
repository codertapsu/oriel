import AppKit
import AVFoundation

/// The camera picture, cut to a circle with a white rim, mirrored like a mirror. Dragging it moves its window.
///
/// With the camera background effect (PLAN §17), its pictures cover the live preview; without them (the effect is
/// off, stepped aside or stopped) the preview shows through, so the bubble is never empty.
final class CameraPreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let effectLayer = CALayer()

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.borderWidth = 3
        layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        effectLayer.contentsGravity = .resizeAspectFill
        effectLayer.isHidden = true
        layer?.addSublayer(effectLayer)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Camera")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    /// Shows the picture mirrored, the way people expect to see themselves.
    func mirror() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }

    /// Shows one picture of the background effect (already mirrored and fitted), or the live preview for nil.
    func showEffect(_ picture: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effectLayer.contents = picture
        effectLayer.isHidden = picture == nil
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        effectLayer.frame = bounds
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}
