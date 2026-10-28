import AppKit
import QuartzCore

/// Draws click highlights: each click adds a ring layer that animates once and is removed, so nothing redraws in
/// between clicks.
final class ClickRingView: NSView {
    static let radius: CGFloat = 22
    static let duration: CFTimeInterval = 0.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The view never takes clicks; they go to the app underneath.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    /// Adds a ring at `point` (view coordinates) that grows and fades, or only fades under Reduce Motion.
    func ring(at point: CGPoint, color: NSColor, reduceMotion: Bool) {
        guard let host = layer else { return }
        let diameter = Self.radius * 2
        let ring = CAShapeLayer()
        ring.frame = CGRect(x: point.x - Self.radius, y: point.y - Self.radius, width: diameter, height: diameter)
        ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: 2, dy: 2), transform: nil)
        ring.fillColor = color.withAlphaComponent(0.2).cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = 3
        ring.opacity = 0
        host.addSublayer(ring)

        let duration = reduceMotion ? Self.duration * 1.5 : Self.duration
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        let group = CAAnimationGroup()
        if reduceMotion {
            group.animations = [fade]
        } else {
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.5
            grow.toValue = 1.2
            grow.duration = duration
            group.animations = [fade, grow]
        }
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(group, forKey: "click")
        let lifetime = Duration.seconds(group.duration + 0.1)
        Task {
            try? await Task.sleep(for: lifetime)
            ring.removeFromSuperlayer()
        }
    }
}
