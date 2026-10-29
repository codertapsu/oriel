import CoreGraphics

/// Draws one vector annotation into a context whose user space is image space (points, y down). Effects
/// (blur, pixelate, spotlight) and patches are part of the image layer and drawn by `EditorRenderer`.
nonisolated enum AnnotationPainter {
    /// Highlighter ink is translucent, so the text under it stays readable.
    static let highlighterOpacity = 0.4

    static func draw(_ item: AnnotationItem, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch item {
        case let .arrow(arrow):
            drawArrow(arrow, in: context)
        case let .line(line):
            context.setStrokeColor(line.color.cgColor)
            context.setLineWidth(line.width)
            context.move(to: line.start)
            context.addLine(to: line.end)
            context.strokePath()
        case let .rect(box):
            context.setStrokeColor(box.color.cgColor)
            context.setLineWidth(box.width)
            context.stroke(box.rect.standardized)
        case let .ellipse(box):
            context.setStrokeColor(box.color.cgColor)
            context.setLineWidth(box.width)
            context.strokeEllipse(in: box.rect.standardized)
        case let .freehand(path):
            stroke(path, color: path.color, in: context)
        case let .highlighter(path):
            stroke(path, color: path.color.withAlpha(path.color.alpha * highlighterOpacity), in: context)
        case let .text(text):
            TextLayout.draw(text.text, at: text.origin, color: text.color, fontSize: text.fontSize, in: context)
        case let .counter(counter):
            StepMarkerPainter.draw(counter, in: context)
        case let .image(layer):
            context.interpolationQuality = .high
            EditorRenderer.drawImage(layer.asset.image, in: layer.rect.standardized, context: context)
        case let .bar(bar):
            context.setFillColor(bar.color.cgColor)
            context.addPath(CGPath(
                roundedRect: bar.rect.standardized,
                cornerWidth: bar.cornerRadius,
                cornerHeight: bar.cornerRadius,
                transform: nil
            ))
            context.fillPath()
        case .blur, .pixelate, .spotlight, .patch:
            break
        }
    }

    /// The pen's sampled points as a smooth curve through the midpoints between them.
    static func smoothedPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            path.addLine(to: points.last ?? first)
            return path
        }
        for index in 1 ..< points.count - 1 {
            let control = points[index]
            let next = points[index + 1]
            path.addQuadCurve(to: CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2), control: control)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    /// The arrowhead triangle: the tip at `end`, the base `headLength` back along the shaft.
    static func headPath(_ arrow: Arrow) -> CGPath? {
        let dx = arrow.end.x - arrow.start.x
        let dy = arrow.end.y - arrow.start.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return nil }
        let unitX = dx / length, unitY = dy / length
        let base = CGPoint(x: arrow.end.x - unitX * arrow.headLength, y: arrow.end.y - unitY * arrow.headLength)
        let half = arrow.headWidth / 2
        let path = CGMutablePath()
        path.move(to: arrow.end)
        path.addLine(to: CGPoint(x: base.x - unitY * half, y: base.y + unitX * half))
        path.addLine(to: CGPoint(x: base.x + unitY * half, y: base.y - unitX * half))
        path.closeSubpath()
        return path
    }

    private static func drawArrow(_ arrow: Arrow, in context: CGContext) {
        guard let head = headPath(arrow) else { return }
        let length = hypot(arrow.end.x - arrow.start.x, arrow.end.y - arrow.start.y)
        context.setStrokeColor(arrow.color.cgColor)
        context.setFillColor(arrow.color.cgColor)
        if length > arrow.headLength {
            // The shaft stops inside the head, so its round cap never pokes through the tip.
            let shaftLength = length - arrow.headLength * 0.8
            let ratio = shaftLength / length
            context.setLineWidth(arrow.width)
            context.move(to: arrow.start)
            context.addLine(to: CGPoint(
                x: arrow.start.x + (arrow.end.x - arrow.start.x) * ratio,
                y: arrow.start.y + (arrow.end.y - arrow.start.y) * ratio
            ))
            context.strokePath()
        }
        context.setLineWidth(max(1, arrow.width * 0.35))
        context.addPath(head)
        context.drawPath(using: .fillStroke)
    }

    private static func stroke(_ path: FreehandPath, color: RGBAColor, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(path.width)
        context.addPath(smoothedPath(path.points))
        context.strokePath()
    }
}
