import AppKit
import QuartzCore

/// The frozen image of one display (or nothing, over the live screen) and what is drawn over it: the dimming with its
/// hole, the selection and its handles, the window or screen highlight, and the crosshair. Layer-hosting, so
/// following the pointer only moves Core Animation shapes and never redraws the full-screen image. Not flipped:
/// layers and view share Cocoa's bottom-left coordinates.
final class OverlayChromeView: NSView {
    weak var handler: OverlayEventHandling?
    let geometry: OverlayGeometry
    private let root = CALayer()
    private let imageLayer = CALayer()
    private let dimLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let selectionLayer = CAShapeLayer()
    private let handlesLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()

    /// `image` nil leaves the view see-through, apart from a tint too faint to see that keeps it hit-testable.
    init(frame: CGRect, image: CGImage?, geometry: OverlayGeometry) {
        self.geometry = geometry
        super.init(frame: frame)
        layer = root // set before wantsLayer: the view hosts this layer tree instead of drawing
        wantsLayer = true
        root.backgroundColor = image == nil ? NSColor(white: 0, alpha: 1 / 255).cgColor : NSColor.black.cgColor
        imageLayer.contents = image
        imageLayer.isHidden = image == nil
        imageLayer.contentsGravity = .resize
        imageLayer.contentsScale = geometry.scale
        imageLayer.magnificationFilter = .nearest
        imageLayer.frame = bounds
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = NSColor(white: 0, alpha: 0.32).cgColor
        selectionLayer.fillColor = nil
        selectionLayer.strokeColor = NSColor.white.cgColor
        selectionLayer.lineWidth = 1
        handlesLayer.fillColor = NSColor.white.cgColor
        handlesLayer.strokeColor = NSColor(white: 0, alpha: 0.45).cgColor
        handlesLayer.lineWidth = 1
        crosshairLayer.fillColor = nil
        crosshairLayer.strokeColor = NSColor(white: 1, alpha: 0.85).cgColor
        crosshairLayer.lineWidth = 1
        for shape in [selectionLayer, crosshairLayer] {
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.6
            shape.shadowRadius = 1
            shape.shadowOffset = .zero
        }
        for sublayer in [imageLayer, dimLayer, highlightLayer, selectionLayer, handlesLayer, crosshairLayer] {
            sublayer.contentsScale = geometry.scale
            sublayer.actions = ["path": NSNull(), "position": NSNull(), "bounds": NSNull(), "hidden": NSNull(), "contents": NSNull()]
            root.addSublayer(sublayer)
        }
        // Pointer moves arrive whether or not Oriel is active; cursor updates need an active-app tracking area,
        // because AppKit does not support them with `.activeAlways`.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Updates the shapes for `scene` (global points).
    func render(_ scene: OverlayScene) {
        let bounds = bounds
        let selection = scene.selection.map(geometry.viewRect)
        let highlight = scene.highlight.map(geometry.viewRect)?.intersection(bounds)

        let dim = CGMutablePath()
        dim.addRect(bounds)
        if let hole = selection ?? (scene.highlightIsStrong ? highlight : nil), !hole.isNull, !hole.isEmpty {
            dim.addRect(hole)
        }
        dimLayer.path = dim

        if let highlight, !highlight.isNull, !highlight.isEmpty {
            highlightLayer.path = CGPath(rect: highlight.insetBy(dx: 1, dy: 1), transform: nil)
            highlightLayer.fillColor = scene.highlightIsStrong ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor : nil
            highlightLayer.strokeColor = scene.highlightIsStrong
                ? NSColor.controlAccentColor.cgColor
                : NSColor(white: 1, alpha: 0.55).cgColor
            highlightLayer.lineWidth = scene.highlightIsStrong ? 2 : 1
            highlightLayer.isHidden = false
        } else {
            highlightLayer.isHidden = true
        }

        if let selection {
            selectionLayer.path = CGPath(rect: selection, transform: nil)
            selectionLayer.isHidden = false
        } else {
            selectionLayer.isHidden = true
        }

        if let selection, scene.showsHandles {
            let handles = CGMutablePath()
            for handle in SelectionHandle.allCases {
                let point = handle.point(in: selection)
                handles.addEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
            }
            handlesLayer.path = handles
            handlesLayer.isHidden = false
        } else {
            handlesLayer.isHidden = true
        }

        if let crosshair = scene.crosshair.map(geometry.viewPoint) {
            let lines = CGMutablePath()
            lines.move(to: CGPoint(x: bounds.minX, y: crosshair.y))
            lines.addLine(to: CGPoint(x: bounds.maxX, y: crosshair.y))
            lines.move(to: CGPoint(x: crosshair.x, y: bounds.minY))
            lines.addLine(to: CGPoint(x: crosshair.x, y: bounds.maxY))
            crosshairLayer.path = lines
            crosshairLayer.isHidden = false
        } else {
            crosshairLayer.isHidden = true
        }
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = globalPoint(of: event)
        handler?.overlay(.mouseMoved(point))
        handler?.overlayCursor(at: point).set()
    }

    override func mouseDown(with event: NSEvent) {
        let point = globalPoint(of: event)
        handler?.overlay(.mouseDown(point, clickCount: event.clickCount))
        handler?.overlayCursor(at: point).set()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = globalPoint(of: event)
        handler?.overlay(.mouseDragged(point))
        handler?.overlayCursor(at: point).set()
    }

    override func mouseUp(with event: NSEvent) {
        let point = globalPoint(of: event)
        handler?.overlay(.mouseUp(point))
        handler?.overlayCursor(at: point).set()
    }

    override func rightMouseDown(with _: NSEvent) {
        handler?.overlay(.rightMouseDown)
    }

    override func cursorUpdate(with event: NSEvent) {
        handler?.overlayCursor(at: globalPoint(of: event)).set()
    }

    private func globalPoint(of event: NSEvent) -> CGPoint {
        geometry.globalPoint(convert(event.locationInWindow, from: nil))
    }
}
