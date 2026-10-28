import CoreGraphics

/// The backdrop behind a padded screenshot: a fill, a drop shadow under the image and rounded image corners.
nonisolated struct BackgroundStyle: Codable, Sendable, Hashable {
    enum Fill: String, Codable, Sendable {
        /// Transparent: only the shadow and the corner radius show.
        case none
        /// `colors[0]`.
        case solid
        /// A linear gradient through `colors`, evenly spaced, along `angle`.
        case gradient
    }

    var fill: Fill
    var colors: [RGBAColor]
    /// Gradient direction in degrees, in image space: 0 runs left to right, 90 top to bottom.
    var angle: Double
    var shadow: Bool
    /// Corner radius of the image card, in points.
    var cornerRadius: CGFloat

    init(fill: Fill, colors: [RGBAColor] = [], angle: Double = 45, shadow: Bool = true, cornerRadius: CGFloat = 12) {
        self.fill = fill
        self.colors = colors
        self.angle = angle
        self.shadow = shadow
        self.cornerRadius = max(cornerRadius, 0)
    }

    /// Whether the backdrop covers the canvas with opaque colour.
    var isOpaque: Bool {
        switch fill {
        case .none: false
        case .solid, .gradient: !colors.isEmpty && colors.allSatisfy { $0.alpha >= 1 }
        }
    }
}
