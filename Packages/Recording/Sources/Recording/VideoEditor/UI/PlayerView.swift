import AppKit
import AVFoundation

/// The video editor's preview (PLAN §17): the player's picture, fitted on black, through the zoom composition.
final class PlayerView: NSView {
    private let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Video")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The rectangle the picture fills, in view coordinates.
    var videoRect: CGRect {
        playerLayer.videoRect
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    /// Clicks go to the window, which plays and pauses on Space; the picture itself takes none.
    override var acceptsFirstResponder: Bool {
        false
    }
}
