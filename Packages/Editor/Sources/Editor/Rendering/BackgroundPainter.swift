import CoreGraphics

/// Draws a background (PLAN §17): the canvas fill, then the card behind the image, its inset in the image's edge
/// colour and the window frame. Draws into canvas space (points, y down).
enum BackgroundPainter {
    /// What a picture background shows while its pixels are missing.
    static let placeholder = RGBAColor(red: 0.55, green: 0.57, blue: 0.62)

    static func fill(_ style: BackgroundStyle, in rect: CGRect, effects: EffectCache, context: CGContext) {
        switch style.fill {
        case .none:
            return
        case .solid:
            guard let color = style.colors.first else { return }
            context.setFillColor(color.cgColor)
            context.fill(rect)
        case .gradient, .radial:
            drawGradient(style, in: rect, context: context)
        case .image:
            drawPicture(style.image, in: rect, effects: effects, context: context)
        }
    }

    /// The card under the image when it shows (an inset or a window frame): the inset in the image's edge colour,
    /// the title bar on top. Clipped to the card's rounded corners.
    static func drawCard(
        _ style: BackgroundStyle,
        document: EditorDocument,
        layout: CanvasLayout,
        effects: EffectCache,
        context: CGContext
    ) {
        guard style.inset > 0 || style.windowFrame != .none else { return }
        let card = layout.cardRect
        context.saveGState()
        defer { context.restoreGState() }
        context.addPath(EditorRenderer.roundedRectPath(card, radius: style.cornerRadius))
        context.clip()
        if style.inset > 0 {
            let color = effects.edgeColor(of: document.base, in: layout.contentRect) ?? .white
            context.setFillColor(color.withAlpha(1).cgColor)
            context.fill(card)
        }
        if style.windowFrame != .none {
            let bar = CGRect(x: card.minX, y: card.minY, width: card.width, height: layout.titleBarHeight)
            WindowFramePainter.draw(style.windowFrame, in: bar, context: context)
        }
    }

    /// The path the image layer is clipped to: rounded like the card, with corners that follow the inset, and square
    /// top corners right under a title bar.
    static func imageClip(_ style: BackgroundStyle?, layout: CanvasLayout) -> CGPath {
        guard let style else { return CGPath(rect: layout.imageRect, transform: nil) }
        let inner = max(0, style.cornerRadius - style.inset)
        let top = style.windowFrame != .none && style.inset == 0 ? 0 : inner
        return EditorRenderer.roundedRectPath(layout.imageRect, top: top, bottom: inner)
    }

    // MARK: - Private

    private static func drawGradient(_ style: BackgroundStyle, in rect: CGRect, context: CGContext) {
        guard style.colors.count > 1 else {
            if let color = style.colors.first {
                context.setFillColor(color.cgColor)
                context.fill(rect)
            }
            return
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: space, colors: style.colors.map(\.cgColor) as CFArray, locations: nil)
        else { return }
        if style.fill == .radial {
            let (center, radius) = GradientGeometry.radial(in: rect)
            context.drawRadialGradient(
                gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        } else {
            let (start, end) = GradientGeometry.linearEndpoints(angle: style.angle, in: rect)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    /// The picture covers the canvas at the device's resolution, so it stays sharp on screen and in the export.
    private static func drawPicture(_ picture: BackgroundImage?, in rect: CGRect, effects: EffectCache, context: CGContext) {
        let transform = context.userSpaceToDeviceSpaceTransform
        let deviceScale = max(hypot(transform.a, transform.b), 0.01)
        let pixels = CGSize(width: rect.width * deviceScale, height: rect.height * deviceScale)
        guard let picture, let image = effects.backgroundImage(picture, pixelSize: pixels, blur: picture.blur * deviceScale) else {
            context.setFillColor(placeholder.cgColor)
            context.fill(rect)
            return
        }
        context.saveGState()
        context.interpolationQuality = .high
        EditorRenderer.drawImage(image, in: rect, context: context)
        context.restoreGState()
    }
}
