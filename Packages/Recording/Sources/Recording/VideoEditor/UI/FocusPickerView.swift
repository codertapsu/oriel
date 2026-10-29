import AppKit

/// Picks where a zoom looks (PLAN §17): a frame of the movie with the zoomed area drawn on it. Drag the area, or
/// click where it should be; with the picker focused, the arrow keys move it (⇧ in larger steps). The area stays
/// inside the frame.
final class FocusPickerView: NSView {
    /// The area's middle moved, normalized to the frame with a top-left origin.
    var onChange: ((CGPoint) -> Void)?

    /// The frame shown under the area.
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    /// The movie's frame size, for the aspect ratio.
    var frameSize = CGSize(width: 16, height: 9) {
        didSet { needsDisplay = true }
    }

    private(set) var scale = 2.0
    private(set) var center = CGPoint(x: 0.5, y: 0.5)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Zoom focus")
        setAccessibilityHelp("Drag the area, or use the arrow keys, to choose where the zoom looks.")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 140)
    }

    /// Shows the area of a zoom at `scale` centred on `center`.
    func show(scale: Double, center: CGPoint) {
        self.scale = scale
        self.center = ZoomTransform.clampedCenter(center, scale: scale)
        let percent = { (value: CGFloat) in Int((value * 100).rounded()) }
        setAccessibilityValue("\(percent(self.center.x)) % across, \(percent(self.center.y)) % down")
        needsDisplay = true
    }

    /// Where the frame is drawn: fitted and centred.
    private var pictureRect: CGRect {
        let bounds = bounds.insetBy(dx: 1, dy: 1)
        guard frameSize.width > 0, frameSize.height > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let fit = min(bounds.width / frameSize.width, bounds.height / frameSize.height)
        let size = CGSize(width: frameSize.width * fit, height: frameSize.height * fit)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    override func draw(_: NSRect) {
        let picture = pictureRect
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: picture, xRadius: 4, yRadius: 4).addClip()
        if let image, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.translateBy(x: picture.minX, y: picture.maxY)
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(origin: .zero, size: picture.size))
            context.restoreGState()
        } else {
            NSColor.quaternarySystemFill.setFill()
            picture.fill()
        }
        // Outside the zoomed area is dimmed.
        let area = areaRect(in: picture)
        let dim = NSBezierPath(rect: picture)
        dim.append(NSBezierPath(rect: area).reversed)
        NSColor.black.withAlphaComponent(0.45).setFill()
        dim.fill()
        NSGraphicsContext.restoreGraphicsState()
        let border = NSBezierPath(rect: area.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        border.stroke()
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let ring = NSBezierPath(roundedRect: picture.insetBy(dx: -0.5, dy: -0.5), xRadius: 4.5, yRadius: 4.5)
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    private func areaRect(in picture: CGRect) -> CGRect {
        let crop = ZoomTransform.cropRect(for: ZoomState(scale: scale, center: center), sourceSize: CGSize(width: 1, height: 1))
        return CGRect(
            x: picture.minX + crop.minX * picture.width,
            y: picture.minY + crop.minY * picture.height,
            width: crop.width * picture.width,
            height: crop.height * picture.height
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        move(to: event)
    }

    override func mouseDragged(with event: NSEvent) {
        move(to: event)
    }

    private func move(to event: NSEvent) {
        let picture = pictureRect
        guard picture.width > 0, picture.height > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let normalized = CGPoint(x: (point.x - picture.minX) / picture.width, y: (point.y - picture.minY) / picture.height)
        set(normalized)
    }

    override func keyDown(with event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 0.1 : 0.02
        switch event.keyCode {
        case 123: set(CGPoint(x: center.x - step, y: center.y))
        case 124: set(CGPoint(x: center.x + step, y: center.y))
        case 125: set(CGPoint(x: center.x, y: center.y + step))
        case 126: set(CGPoint(x: center.x, y: center.y - step))
        default: super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    private func set(_ point: CGPoint) {
        show(scale: scale, center: point)
        onChange?(center)
    }
}
