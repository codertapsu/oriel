import AppKit
import QuartzCore

/// One display's overlay: see-through, apart from a tint too faint to see that keeps it hit-testable, with the
/// scene drawn as Core Animation shapes, so following the pointer only moves paths and badges. Lines are 1 point,
/// in the ruler's color with a dark halo so they show on any background, and sit on pixel boundaries.
final class RulerCanvasView: NSView {
    weak var handler: RulerEventHandling?
    let mapping: RulerViewMapping
    let notice = RulerNoticeView()
    let hintBar = RulerHintBar()
    var lineColor: NSColor {
        didSet { applyColors() }
    }

    private let root = CALayer()
    private let crosshairLayer = CAShapeLayer()
    private let areaLayer = CAShapeLayer()
    private let handlesLayer = CAShapeLayer()
    private let boxLayer = CAShapeLayer()
    private let pinnedLayer = CAShapeLayer()
    private let fitLayer = CAShapeLayer()
    private let segmentsLayer = CAShapeLayer()
    private let guidesLayer = CAShapeLayer()
    private let selectedGuidesLayer = CAShapeLayer()
    private let previewGuideLayer = CAShapeLayer()
    private var badges: [RulerBadge] = []

    init(frame: CGRect, display: RulerDisplay, lineColor: NSColor) {
        mapping = RulerViewMapping(display: display)
        self.lineColor = lineColor
        super.init(frame: frame)
        layer = root // set before wantsLayer: the view hosts this layer tree instead of drawing
        wantsLayer = true
        root.backgroundColor = NSColor(white: 0, alpha: 1 / 255).cgColor
        let shapes = [
            crosshairLayer, boxLayer, fitLayer, pinnedLayer, areaLayer, guidesLayer, selectedGuidesLayer, previewGuideLayer,
            segmentsLayer, handlesLayer,
        ]
        for shape in shapes {
            shape.contentsScale = display.scale
            shape.fillColor = nil
            shape.lineWidth = 1
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.55
            shape.shadowRadius = 1
            shape.shadowOffset = .zero
            shape.actions = ["path": NSNull(), "hidden": NSNull(), "position": NSNull(), "bounds": NSNull()]
            root.addSublayer(shape)
        }
        boxLayer.lineDashPattern = [4, 3]
        fitLayer.lineDashPattern = [5, 3]
        previewGuideLayer.lineDashPattern = [6, 4]
        selectedGuidesLayer.lineWidth = 2
        pinnedLayer.lineWidth = 1.5
        handlesLayer.lineWidth = 1
        applyColors()
        notice.isHidden = true
        addSubview(notice)
        hintBar.isHidden = true
        addSubview(hintBar)
        // Pointer moves arrive whether or not Oriel is active; cursor updates need an active-app tracking area.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeInActiveApp, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Screen Ruler")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Drawing

    func render(_ scene: RulerScene) {
        crosshairLayer.path = scene.crosshair.map(crosshairPath)
        areaLayer.path = scene.area.map { CGPath(rect: crisp($0), transform: nil) }
        handlesLayer.path = scene.showsHandles ? scene.area.map(handlesPath) : nil
        boxLayer.path = scene.measuredBox.map { CGPath(rect: crisp($0), transform: nil) }
        pinnedLayer.path = scene.pinnedBox.map { CGPath(rect: crisp($0), transform: nil) }
        fitLayer.path = scene.fitBox.map { CGPath(rect: crisp($0), transform: nil) }
        segmentsLayer.path = segmentsPath(scene.segments)
        guidesLayer.path = guidesPath(scene.guides.filter { !$0.isSelected && !$0.isPreview })
        selectedGuidesLayer.path = guidesPath(scene.guides.filter(\.isSelected))
        previewGuideLayer.path = guidesPath(scene.guides.filter(\.isPreview))
        renderLabels(scene.labels)
        if let card = scene.notice {
            notice.show(card)
            let size = notice.frame.size
            notice.setFrameOrigin(CGPoint(x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded()))
            notice.isHidden = false
        } else {
            notice.isHidden = true
        }
    }

    /// The hint bar on this display, or none: it shows only where the pointer is. `flash` replaces the keys with a line
    /// such as "Copied 320 × 240 pt". The bar keeps to the bottom, and moves to the top when the pointer comes near it.
    func showHint(_ hint: (mode: String, instruction: String, keys: [KeyHint])?, flash: String?, pointer: CGPoint?) {
        guard let hint else {
            hintBar.isHidden = true
            return
        }
        if let flash {
            hintBar.flash(flash, symbol: "checkmark.circle.fill")
        } else {
            hintBar.show(mode: hint.mode, instruction: hint.instruction, keys: hint.keys)
        }
        let size = hintBar.frame.size
        var origin = CGPoint(x: ((bounds.width - size.width) / 2).rounded(), y: 40)
        if let pointer, mapping.viewPoint(pointer).y < origin.y + size.height + 48 {
            origin.y = bounds.height - 64 - size.height
        }
        hintBar.setFrameOrigin(origin)
        hintBar.isHidden = false
    }

    private func applyColors() {
        let color = lineColor.cgColor
        for shape in [areaLayer, boxLayer, pinnedLayer, fitLayer, segmentsLayer, guidesLayer, selectedGuidesLayer, previewGuideLayer] {
            shape.strokeColor = color
        }
        crosshairLayer.strokeColor = lineColor.withAlphaComponent(0.7).cgColor
        areaLayer.fillColor = lineColor.withAlphaComponent(0.1).cgColor
        pinnedLayer.fillColor = lineColor.withAlphaComponent(0.12).cgColor
        boxLayer.fillColor = lineColor.withAlphaComponent(0.06).cgColor
        handlesLayer.fillColor = NSColor.white.cgColor
        handlesLayer.strokeColor = NSColor(white: 0, alpha: 0.5).cgColor
        handlesLayer.shadowOpacity = 0.3
    }

    /// A rectangle in view coordinates whose 1-point edges cover whole pixels.
    private func crisp(_ rect: CGRect) -> CGRect {
        let view = mapping.viewRect(rect)
        guard mapping.display.scale < 2 else { return view }
        return CGRect(
            x: view.minX.rounded() + 0.5,
            y: view.minY.rounded() + 0.5,
            width: view.width.rounded() - 1,
            height: view.height.rounded() - 1
        )
    }

    /// A coordinate where a 1-point line covers whole pixels: on a 1× display, the middle of a pixel.
    private func crisp(_ value: CGFloat) -> CGFloat {
        mapping.display.scale < 2 ? value.rounded(.down) + 0.5 : value
    }

    private func crosshairPath(_ point: CGPoint) -> CGPath {
        let view = mapping.viewPoint(point)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: crisp(view.y)))
        path.addLine(to: CGPoint(x: bounds.maxX, y: crisp(view.y)))
        path.move(to: CGPoint(x: crisp(view.x), y: 0))
        path.addLine(to: CGPoint(x: crisp(view.x), y: bounds.maxY))
        return path
    }

    private func handlesPath(_ rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        for handle in RulerHandle.allCases {
            let point = mapping.viewPoint(handle.point(on: rect))
            path.addEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
        }
        return path
    }

    /// Each segment with a short tick across both ends.
    private func segmentsPath(_ segments: [RulerScene.Segment]) -> CGPath? {
        guard !segments.isEmpty else { return nil }
        let path = CGMutablePath()
        let tick: CGFloat = 4
        for segment in segments {
            let from = mapping.viewPoint(segment.from)
            let to = mapping.viewPoint(segment.to)
            if abs(from.y - to.y) < 0.01 {
                let y = crisp(from.y)
                path.move(to: CGPoint(x: from.x, y: y))
                path.addLine(to: CGPoint(x: to.x, y: y))
                for x in [from.x, to.x] {
                    path.move(to: CGPoint(x: x, y: y - tick))
                    path.addLine(to: CGPoint(x: x, y: y + tick))
                }
            } else {
                let x = crisp(from.x)
                path.move(to: CGPoint(x: x, y: from.y))
                path.addLine(to: CGPoint(x: x, y: to.y))
                for y in [from.y, to.y] {
                    path.move(to: CGPoint(x: x - tick, y: y))
                    path.addLine(to: CGPoint(x: x + tick, y: y))
                }
            }
        }
        return path
    }

    private func guidesPath(_ guides: [RulerScene.GuideLine]) -> CGPath? {
        guard !guides.isEmpty else { return nil }
        let path = CGMutablePath()
        for guide in guides {
            if guide.orientation == .vertical {
                let x = crisp(mapping.viewX(guide.position))
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: bounds.maxY))
            } else {
                let y = crisp(mapping.viewY(guide.position))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: bounds.maxX, y: y))
            }
        }
        return path
    }

    // MARK: Labels

    private func renderLabels(_ labels: [RulerScene.Label]) {
        while badges.count < labels.count {
            let badge = RulerBadge()
            addSubview(badge, positioned: .below, relativeTo: notice)
            badges.append(badge)
        }
        for (index, badge) in badges.enumerated() {
            guard index < labels.count else {
                badge.isHidden = true
                continue
            }
            let label = labels[index]
            badge.show(label.text, detail: label.detail, style: label.style)
            badge.setFrameOrigin(origin(for: badge.frame.size, label: label))
            badge.isHidden = false
        }
    }

    /// Where a badge goes for its placement, kept on the display.
    private func origin(for size: CGSize, label: RulerScene.Label) -> CGPoint {
        let anchor = mapping.viewPoint(label.anchor)
        var origin: CGPoint
        switch label.placement {
        case .center:
            origin = CGPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height / 2)
        case .beside:
            origin = CGPoint(x: anchor.x + 16, y: anchor.y - 16 - size.height)
            if origin.x + size.width > bounds.maxX - 4 {
                origin.x = anchor.x - 16 - size.width
            }
            if origin.y < 4 {
                origin.y = anchor.y + 16
            }
        case .below:
            origin = CGPoint(x: anchor.x - size.width / 2, y: anchor.y - 8 - size.height)
            if origin.y < 4 {
                origin.y = anchor.y + 8
            }
        }
        origin.x = min(max(origin.x, 4), bounds.maxX - size.width - 4)
        origin.y = min(max(origin.y, 4), bounds.maxY - size.height - 4)
        return CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
    }

    // MARK: Events

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseMoved(with event: NSEvent) {
        handler?.rulerMouseMoved(to: globalPoint(of: event))
        handler?.rulerCursor().set()
    }

    override func mouseDown(with event: NSEvent) {
        handler?.rulerMouseDown(at: globalPoint(of: event), clickCount: event.clickCount)
        handler?.rulerCursor().set()
    }

    override func mouseDragged(with event: NSEvent) {
        handler?.rulerMouseDragged(to: globalPoint(of: event), modifiers: event.modifierFlags)
        handler?.rulerCursor().set()
    }

    override func mouseUp(with event: NSEvent) {
        handler?.rulerMouseUp(at: globalPoint(of: event))
        handler?.rulerCursor().set()
    }

    override func rightMouseDown(with event: NSEvent) {
        handler?.rulerRightMouseDown(at: globalPoint(of: event))
    }

    override func cursorUpdate(with _: NSEvent) {
        handler?.rulerCursor().set()
    }

    private func globalPoint(of event: NSEvent) -> CGPoint {
        mapping.globalPoint(convert(event.locationInWindow, from: nil))
    }
}
