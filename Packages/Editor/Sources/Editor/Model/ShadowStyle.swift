import CoreGraphics

/// The drop shadow under the image card, in points.
nonisolated struct ShadowStyle: Codable, Sendable, Hashable {
    /// The blur radius.
    var radius: CGFloat
    /// 0 (invisible) … 1 (black at the card's edge).
    var opacity: Double
    /// How far the shadow falls from the card; positive `height` is downwards.
    var offset: CGSize

    init(radius: CGFloat, opacity: Double, offset: CGSize) {
        self.radius = min(max(radius, 0), Self.radiusRange.upperBound)
        self.opacity = min(max(opacity, 0), 1)
        self.offset = offset
    }

    static let radiusRange: ClosedRange<CGFloat> = 0 ... 80
    static let offsetRange: ClosedRange<CGFloat> = -60 ... 60

    /// The shadow a background gets until the user sets one: soft and close, scaled with the padding so it never
    /// reaches the canvas edge. It is the look of documents made before the shadow could be set.
    static func automatic(padding: Padding) -> ShadowStyle {
        let radius = min(28, max(4, min(padding.top, padding.left, padding.bottom, padding.right) * 0.4))
        return ShadowStyle(radius: radius, opacity: 0.38, offset: CGSize(width: 0, height: radius * 0.35))
    }
}
