import CoreGraphics

/// The backdrop behind a padded screenshot (PLAN §17, "social-ready shots"): a fill, a drop shadow under the image,
/// rounded corners, an inset in the image's own edge colour, an optional window frame, and the canvas's aspect with
/// where the image sits in it. The padding itself is `EditorDocument.canvasPadding`.
nonisolated struct BackgroundStyle: Sendable, Hashable {
    enum Fill: String, Codable, Sendable, CaseIterable {
        /// Transparent: only the shadow, the corners and the frame show.
        case none
        /// `colors[0]`.
        case solid
        /// A linear gradient through `colors`, evenly spaced, along `angle`.
        case gradient
        /// A radial gradient through `colors`, from the canvas's centre to its corners.
        case radial
        /// `image`, covering the canvas.
        case image
    }

    var fill: Fill
    var colors: [RGBAColor]
    /// Gradient direction in degrees, in image space: 0 runs left to right, 90 top to bottom.
    var angle: Double
    var image: BackgroundImage?
    var shadow: Bool
    /// Nil: `ShadowStyle.automatic`, which follows the padding.
    var shadowStyle: ShadowStyle?
    /// Corner radius of the image card, in points.
    var cornerRadius: CGFloat
    /// A margin around the image inside the card, filled with the colour of the image's edges, in points.
    var inset: CGFloat
    var aspect: CanvasAspect
    var alignment: CanvasAlignment
    var windowFrame: WindowFrame

    init(
        fill: Fill,
        colors: [RGBAColor] = [],
        angle: Double = 45,
        image: BackgroundImage? = nil,
        shadow: Bool = true,
        shadowStyle: ShadowStyle? = nil,
        cornerRadius: CGFloat = 12,
        inset: CGFloat = 0,
        aspect: CanvasAspect = .auto,
        alignment: CanvasAlignment = .center,
        windowFrame: WindowFrame = .none
    ) {
        self.fill = fill
        self.colors = colors
        self.angle = angle
        self.image = image
        self.shadow = shadow
        self.shadowStyle = shadowStyle
        self.cornerRadius = max(cornerRadius, 0)
        self.inset = max(inset, 0)
        self.aspect = aspect
        self.alignment = alignment
        self.windowFrame = windowFrame
    }

    /// Whether the backdrop covers the canvas with opaque colour.
    var isOpaque: Bool {
        switch fill {
        case .none: false
        case .solid, .gradient, .radial: !colors.isEmpty && colors.allSatisfy { $0.alpha >= 1 }
        // A picture covers the whole canvas.
        case .image: image != nil
        }
    }

    /// The shadow as drawn: the one set, or the automatic one for `padding`.
    func resolvedShadow(padding: Padding) -> ShadowStyle {
        shadowStyle ?? .automatic(padding: padding)
    }

    /// The same layout, shadow, corners and frame with another fill: what choosing a preset changes.
    func withFill(of other: BackgroundStyle) -> BackgroundStyle {
        var style = self
        style.fill = other.fill
        style.colors = other.colors
        style.angle = other.angle
        style.image = other.image
        return style
    }

    static let cornerRadiusRange: ClosedRange<CGFloat> = 0 ... 48
    static let insetRange: ClosedRange<CGFloat> = 0 ... 80
    static let paddingRange: ClosedRange<CGFloat> = 0 ... 240
}

/// Version 1 documents have only `fill`, `colors`, `angle`, `shadow` and `cornerRadius`; everything added since
/// decodes to its default, so they look as they did.
extension BackgroundStyle: Codable {
    private enum CodingKeys: String, CodingKey {
        case fill, colors, angle, image, shadow, shadowStyle, cornerRadius, inset, aspect, alignment, windowFrame
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            fill: container.decode(Fill.self, forKey: .fill),
            colors: container.decodeIfPresent([RGBAColor].self, forKey: .colors) ?? [],
            angle: container.decodeIfPresent(Double.self, forKey: .angle) ?? 45,
            image: container.decodeIfPresent(BackgroundImage.self, forKey: .image),
            shadow: container.decodeIfPresent(Bool.self, forKey: .shadow) ?? true,
            shadowStyle: container.decodeIfPresent(ShadowStyle.self, forKey: .shadowStyle),
            cornerRadius: container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 12,
            inset: container.decodeIfPresent(CGFloat.self, forKey: .inset) ?? 0,
            aspect: container.decodeIfPresent(CanvasAspect.self, forKey: .aspect) ?? .auto,
            alignment: container.decodeIfPresent(CanvasAlignment.self, forKey: .alignment) ?? .center,
            windowFrame: container.decodeIfPresent(WindowFrame.self, forKey: .windowFrame) ?? WindowFrame.none
        )
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fill, forKey: .fill)
        try container.encode(colors, forKey: .colors)
        try container.encode(angle, forKey: .angle)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encode(shadow, forKey: .shadow)
        try container.encodeIfPresent(shadowStyle, forKey: .shadowStyle)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(inset, forKey: .inset)
        try container.encode(aspect, forKey: .aspect)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(windowFrame, forKey: .windowFrame)
    }
}
