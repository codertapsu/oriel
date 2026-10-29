import CoreGraphics

/// Draws a step marker: the body (circle or rounded square) and its pointer in the marker's colour with one white
/// outline around both, and the label in white or black, whichever reads on that colour.
nonisolated enum StepMarkerPainter {
    /// The outline's width, as a fraction of the radius.
    static let outlineFraction: CGFloat = 0.12

    static func draw(_ counter: Counter, in context: CGContext) {
        var paths = [StepGeometry.bodyPath(counter)]
        if let pointer = StepGeometry.pointerPath(counter) {
            paths.append(pointer)
        }
        let outline = counter.radius * outlineFraction
        context.saveGState()
        defer { context.restoreGState() }
        // A white stroke twice the outline's width, then the fill over it: what is left outside is one clean
        // outline around the body and the pointer together, with no seam where they meet.
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(outline * 2)
        context.setLineJoin(.round)
        for path in paths {
            context.addPath(path)
            context.strokePath()
        }
        context.setFillColor(counter.color.cgColor)
        for path in paths {
            context.addPath(path)
            context.fillPath()
        }
        let label = counter.text
        let textColor: RGBAColor = counter.color.luminance > 0.7 ? .black : .white
        TextLayout.draw(
            label,
            centeredOn: counter.center,
            color: textColor,
            fontSize: fontSize(for: label, radius: counter.radius),
            in: context
        )
    }

    /// The label's size: large for one character, smaller for more, so "12", "AB" and "VIII" all fit the body.
    static func fontSize(for label: String, radius: CGFloat) -> CGFloat {
        var size = radius * (label.count > 2 ? 0.75 : label.count == 2 ? 0.95 : 1.15)
        let room = radius * 1.55
        let width = TextLayout.size(of: label, fontSize: size).width
        if width > room {
            size *= room / width
        }
        return max(size, 1)
    }
}
