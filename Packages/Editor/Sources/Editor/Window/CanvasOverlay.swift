import AppKit

/// The editing UI drawn over the rendered document, in view space so handles keep their size at any zoom:
/// selection outlines and handles, the rubber band and the crop tool.
enum CanvasOverlay {
    static let handleSize: CGFloat = 8

    static func draw(session: EditorSession, zoom: CGFloat, in context: CGContext) {
        let layout = session.layout
        func toView(_ rect: CGRect) -> CGRect {
            let canvas = layout.canvasRect(fromImage: rect)
            return CGRect(x: canvas.minX * zoom, y: canvas.minY * zoom, width: canvas.width * zoom, height: canvas.height * zoom)
        }
        func toView(_ point: CGPoint) -> CGPoint {
            let canvas = layout.canvasPoint(fromImage: point)
            return CGPoint(x: canvas.x * zoom, y: canvas.y * zoom)
        }
        context.saveGState()
        defer { context.restoreGState() }
        if session.tool == .crop, let draft = session.cropDraft {
            let canvas = CGRect(x: 0, y: 0, width: layout.canvasSize.width * zoom, height: layout.canvasSize.height * zoom)
            drawCrop(toView(draft), in: canvas, pixels: draft.size, scale: session.document.base.scale, context: context)
            return
        }
        let accent = NSColor.controlAccentColor.cgColor
        context.setStrokeColor(accent)
        context.setLineWidth(1)
        let single = session.selection.count == 1
        for id in session.selection where id != session.editingTextID {
            guard let item = session.document.item(withID: id) else { continue }
            // A single arrow or line shows its end handles only; a frame around it would just be noise.
            let isSegment = item.kind == .arrow || item.kind == .line
            if !(single && isSegment) {
                context.stroke(toView(item.frame).insetBy(dx: -2.5, dy: -2.5))
            }
            if single {
                for handle in item.handles {
                    drawHandle(at: toView(item.position(of: handle)), color: accent, context: context)
                }
            }
        }
        if let marquee = session.marquee {
            let rect = toView(marquee)
            context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
            context.fill(rect)
            context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        }
    }

    private static func drawHandle(at point: CGPoint, color: CGColor, context: CGContext) {
        let rect = CGRect(x: point.x - handleSize / 2, y: point.y - handleSize / 2, width: handleSize, height: handleSize)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.setStrokeColor(color)
        context.setLineWidth(1.5)
        context.stroke(rect)
    }

    /// Dims everything outside the crop, frames it with thirds lines and handles, and labels its pixel size.
    private static func drawCrop(_ rect: CGRect, in canvas: CGRect, pixels: CGSize, scale: CGFloat, context: CGContext) {
        context.addRect(canvas)
        context.addRect(rect)
        context.setFillColor(CGColor(gray: 0, alpha: 0.5))
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.45))
        context.setLineWidth(1)
        for fraction in [1.0 / 3, 2.0 / 3] {
            context.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
            context.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
        }
        context.strokePath()
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(1.5)
        context.stroke(rect)
        for handle in SelectionHandle.boxHandles {
            drawHandle(at: handle.point(in: rect), color: CGColor(gray: 0.2, alpha: 1), context: context)
        }
        let label = "\(Int((pixels.width * scale).rounded())) × \(Int((pixels.height * scale).rounded()))"
        let size = TextLayout.size(of: label, fontSize: 11)
        let origin = CGPoint(x: rect.minX + 6, y: max(rect.minY - size.height - 8, canvas.minY + 4))
        let pill = CGRect(x: origin.x - 5, y: origin.y - 2, width: size.width + 10, height: size.height + 4)
        context.addPath(EditorRenderer.roundedRectPath(pill, radius: pill.height / 2))
        context.setFillColor(CGColor(gray: 0, alpha: 0.65))
        context.fillPath()
        TextLayout.draw(label, at: origin, color: .white, fontSize: 11, in: context)
    }
}
