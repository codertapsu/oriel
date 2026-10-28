import CoreGraphics

/// The one renderer (PLAN §7.5): the canvas view, the clipboard, every export format and drag-out all draw
/// through `draw(_:in:options:effects:)`, so what you see is what you export.
///
/// Order: background fill, drop shadow, then the image layer (base pixels, blur and pixelate, spotlight dimming)
/// clipped to the rounded image card, then the vector annotations in z-order.
enum EditorRenderer {
    /// Renders into a bitmap or PDF context in its native coordinate space (origin bottom-left, y up), at
    /// `scale` device units per point. The context should be the canvas size times `scale`.
    static func render(
        _ document: EditorDocument,
        into context: CGContext,
        scale: CGFloat,
        options: RenderOptions = RenderOptions(),
        effects: EffectCache? = nil
    ) {
        let layout = CanvasLayout(document: document, showsUncroppedImage: options.showsUncroppedImage)
        context.saveGState()
        context.translateBy(x: 0, y: layout.canvasSize.height * scale)
        context.scaleBy(x: scale, y: -scale)
        draw(document, in: context, options: options, effects: effects ?? EffectCache())
        context.restoreGState()
    }

    /// The flattened document as a bitmap at `scale` pixels per point (the base image's own scale reproduces its
    /// pixels exactly).
    static func makeImage(
        _ document: EditorDocument,
        scale: CGFloat,
        options: RenderOptions = RenderOptions(),
        effects: EffectCache? = nil
    ) -> CGImage? {
        let size = CanvasLayout(document: document, showsUncroppedImage: options.showsUncroppedImage).pixelSize(scale: scale)
        guard let context = makeBitmapContext(width: size.width, height: size.height, preferring: document.base.image.colorSpace)
        else { return nil }
        render(document, into: context, scale: scale, options: options, effects: effects)
        return context.makeImage()
    }

    /// Draws into a context whose user space is already canvas points with the origin at the top-left (y down),
    /// as in the flipped canvas view.
    static func draw(_ document: EditorDocument, in context: CGContext, options: RenderOptions, effects: EffectCache) {
        let layout = CanvasLayout(document: document, showsUncroppedImage: options.showsUncroppedImage)
        let background = options.showsUncroppedImage ? nil : document.background
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: layout.canvasBounds)
        if let matte = options.matte {
            context.setFillColor(matte.cgColor)
            context.fill(layout.canvasBounds)
        }
        if let background {
            fill(background, in: layout.canvasBounds, context: context)
            if background.shadow {
                drawShadow(layout: layout, cornerRadius: background.cornerRadius, effects: effects, context: context)
            }
        }
        drawImageLayer(
            document,
            layout: layout,
            cornerRadius: background?.cornerRadius ?? 0,
            options: options,
            effects: effects,
            context: context
        )
        context.translateBy(x: layout.offset.dx, y: layout.offset.dy)
        for item in document.items where !item.isImageLayer && !options.hiddenItems.contains(item.id) {
            AnnotationPainter.draw(item, in: context)
        }
    }

    /// A rounded-rect path whose radius never exceeds half the shorter side (CGPath requires that).
    static func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let radius = min(max(radius, 0), rect.width / 2, rect.height / 2)
        guard radius > 0, rect.width > 0, rect.height > 0 else { return CGPath(rect: rect, transform: nil) }
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// An 8-bit RGBA bitmap in `preferred` space when it is an RGB space that can be drawn into, else sRGB.
    static func makeBitmapContext(width: Int, height: Int, preferring preferred: CGColorSpace?) -> CGContext? {
        func bitmap(in space: CGColorSpace) -> CGContext? {
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        if let preferred, preferred.model == .rgb, preferred.supportsOutput, let context = bitmap(in: preferred) {
            return context
        }
        return CGColorSpace(name: CGColorSpace.sRGB).flatMap(bitmap(in:))
    }

    /// Draws `image` upright into `rect` of a y-down user space.
    static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    // MARK: - Layers

    private static func fill(_ style: BackgroundStyle, in rect: CGRect, context: CGContext) {
        switch style.fill {
        case .none:
            return
        case .solid:
            guard let color = style.colors.first else { return }
            context.setFillColor(color.cgColor)
            context.fill(rect)
        case .gradient:
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
            let radians = style.angle * .pi / 180
            let direction = CGVector(dx: cos(radians), dy: sin(radians))
            let reach = abs(direction.dx) * rect.width / 2 + abs(direction.dy) * rect.height / 2
            let start = CGPoint(x: rect.midX - direction.dx * reach, y: rect.midY - direction.dy * reach)
            let end = CGPoint(x: rect.midX + direction.dx * reach, y: rect.midY + direction.dy * reach)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    /// A soft shadow under the card, kept outside it so a transparent image never shows a shadow through itself.
    private static func drawShadow(layout: CanvasLayout, cornerRadius: CGFloat, effects: EffectCache, context: CGContext) {
        let card = layout.cardRect
        let padding = layout.padding
        let blur = min(28, max(4, min(padding.top, padding.left, padding.bottom, padding.right) * 0.4))
        guard let shadow = effects.shadow(size: card.size, cornerRadius: cornerRadius, blur: blur) else { return }
        context.saveGState()
        context.addRect(layout.canvasBounds)
        context.addPath(roundedRectPath(card, radius: cornerRadius))
        context.clip(using: .evenOdd)
        context.setAlpha(0.38)
        drawImage(shadow.image, in: shadow.rect.offsetBy(dx: card.minX, dy: card.minY + blur * 0.35), context: context)
        context.restoreGState()
    }

    private static func drawImageLayer(
        _ document: EditorDocument,
        layout: CanvasLayout,
        cornerRadius: CGFloat,
        options: RenderOptions,
        effects: EffectCache,
        context: CGContext
    ) {
        let base = document.base
        context.saveGState()
        defer { context.restoreGState() }
        context.addPath(roundedRectPath(layout.cardRect, radius: cornerRadius))
        context.clip()
        context.translateBy(x: layout.offset.dx, y: layout.offset.dy)
        // Device pixels per base pixel: at 1:1 or larger, draw pixels as they are; smaller, filter well.
        let transform = context.userSpaceToDeviceSpaceTransform
        let deviceScale = hypot(transform.a, transform.b)
        context.interpolationQuality = deviceScale >= base.scale * 0.999 ? .none : .high
        drawImage(base.image, in: base.bounds, context: context)
        var spotlights: [Region] = []
        for item in document.items where !options.hiddenItems.contains(item.id) {
            switch item {
            case let .blur(region):
                drawEffect(.blur, region: region, base: base, effects: effects, context: context)
            case let .pixelate(region):
                drawEffect(.pixelate, region: region, base: base, effects: effects, context: context)
            case let .spotlight(region):
                spotlights.append(region)
            default:
                break
            }
        }
        dim(around: spotlights, covering: layout.contentRect, context: context)
    }

    private static func drawEffect(_ kind: AnnotationKind, region: Region, base: ImageRef, effects: EffectCache, context: CGContext) {
        guard let output = effects.effect(kind, region: region, base: base) else { return }
        context.saveGState()
        context.clip(to: region.rect.standardized)
        if kind == .pixelate {
            context.interpolationQuality = .none
        }
        drawImage(output.image, in: output.rect, context: context)
        context.restoreGState()
    }

    /// Darkens `area` except inside the spotlights. Each spotlight narrows the clip, so overlapping spotlights
    /// add up to their union instead of cancelling out.
    private static func dim(around spotlights: [Region], covering area: CGRect, context: CGContext) {
        guard !spotlights.isEmpty else { return }
        context.saveGState()
        let outer = area.insetBy(dx: -1, dy: -1)
        for spotlight in spotlights {
            context.addRect(outer)
            context.addPath(roundedRectPath(spotlight.rect.standardized, radius: Region.spotlightCornerRadius))
            context.clip(using: .evenOdd)
        }
        context.setFillColor(CGColor(gray: 0, alpha: 0.55))
        context.fill(outer)
        context.restoreGState()
    }
}
