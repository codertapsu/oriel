import CoreGraphics

/// The one renderer (PLAN §7.5): the canvas view, the clipboard, every export format and drag-out all draw
/// through `draw(_:in:options:effects:)`, so what you see is what you export.
///
/// Order: background fill, drop shadow, the card (inset and window frame), then the image layer (base pixels,
/// patches, blur and pixelate, the tone-down, spotlight dimming) clipped to the image's rounded corners, then the
/// vector annotations in z-order.
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
            BackgroundPainter.fill(background, in: layout.canvasBounds, effects: effects, context: context)
            if background.shadow {
                drawShadow(
                    background.resolvedShadow(padding: layout.padding),
                    layout: layout,
                    cornerRadius: background.cornerRadius,
                    effects: effects,
                    context: context
                )
            }
            BackgroundPainter.drawCard(background, document: document, layout: layout, effects: effects, context: context)
        }
        drawImageLayer(
            document,
            layout: layout,
            clip: BackgroundPainter.imageClip(background, layout: layout),
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
    nonisolated static func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let radius = min(max(radius, 0), rect.width / 2, rect.height / 2)
        guard radius > 0, rect.width > 0, rect.height > 0 else { return CGPath(rect: rect, transform: nil) }
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// A rect with one radius for its top corners (the `minY` side, in a y-down space) and another for its bottom
    /// corners, each kept within half the shorter side.
    nonisolated static func roundedRectPath(_ rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let limit = max(0, min(rect.width, rect.height) / 2)
        let top = min(max(top, 0), limit), bottom = min(max(bottom, 0), limit)
        guard top != bottom else { return roundedRectPath(rect, radius: top) }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: top)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: bottom)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: bottom)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: top)
        path.closeSubpath()
        return path
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
    nonisolated static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    // MARK: - Layers

    /// A soft shadow under the card, kept outside it so a transparent image never shows a shadow through itself.
    private static func drawShadow(
        _ shadow: ShadowStyle,
        layout: CanvasLayout,
        cornerRadius: CGFloat,
        effects: EffectCache,
        context: CGContext
    ) {
        guard shadow.opacity > 0 else { return }
        let card = layout.cardRect
        guard let image = effects.shadow(size: card.size, cornerRadius: cornerRadius, blur: shadow.radius) else { return }
        context.saveGState()
        context.addRect(layout.canvasBounds)
        context.addPath(roundedRectPath(card, radius: cornerRadius))
        context.clip(using: .evenOdd)
        context.setAlpha(shadow.opacity)
        context.interpolationQuality = .high
        drawImage(
            image.image,
            in: image.rect.offsetBy(dx: card.minX + shadow.offset.width, dy: card.minY + shadow.offset.height),
            context: context
        )
        context.restoreGState()
    }

    private static func drawImageLayer(
        _ document: EditorDocument,
        layout: CanvasLayout,
        clip: CGPath,
        options: RenderOptions,
        effects: EffectCache,
        context: CGContext
    ) {
        let base = document.base
        context.saveGState()
        defer { context.restoreGState() }
        context.addPath(clip)
        context.clip()
        context.translateBy(x: layout.offset.dx, y: layout.offset.dy)
        // Device pixels per base pixel: at 1:1 or larger, draw pixels as they are; smaller, filter well.
        let transform = context.userSpaceToDeviceSpaceTransform
        let deviceScale = hypot(transform.a, transform.b)
        context.interpolationQuality = deviceScale >= base.scale * 0.999 ? .none : .high
        drawImage(base.image, in: base.bounds, context: context)
        let visible = document.items.filter { !options.hiddenItems.contains($0.id) }
        for case let .patch(layer) in visible {
            drawImage(layer.asset.image, in: layer.rect.standardized, context: context)
        }
        var spotlights: [Region] = []
        for item in visible {
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
        if let tone = document.tone {
            toneDown(layout.contentRect, amount: tone, context: context)
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

    /// Washes the image out behind the annotations: takes away colour, then lightens, both by `amount` (0…1). Drawn
    /// with blend modes over what is already there, so it works the same on screen, in bitmaps and in PDFs.
    private static func toneDown(_ area: CGRect, amount: Double, context: CGContext) {
        let amount = min(max(amount, 0), 1)
        guard amount > 0 else { return }
        context.saveGState()
        context.setBlendMode(.saturation)
        context.setFillColor(CGColor(gray: 0.5, alpha: amount))
        context.fill(area)
        context.setBlendMode(.normal)
        context.setFillColor(CGColor(gray: 1, alpha: amount * 0.6))
        context.fill(area)
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
