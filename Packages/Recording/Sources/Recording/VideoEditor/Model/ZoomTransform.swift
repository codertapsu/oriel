import CoreGraphics

/// The geometry of a zoomed frame (PLAN §17): which source pixels are shown and how they fill the output. Pure.
///
/// The part shown is always inside the frame, so a zoom near an edge slides inwards instead of showing black
/// borders, and it is scaled to fill the output exactly.
nonisolated enum ZoomTransform {
    /// The part of a frame of `sourceSize` pixels that `state` shows, top-left origin: `sourceSize / scale` large,
    /// centred on `state.center` unless that would cross an edge.
    static func cropRect(for state: ZoomState, sourceSize: CGSize) -> CGRect {
        let scale = state.scale.isFinite ? max(state.scale, 1) : 1
        let width = sourceSize.width / scale
        let height = sourceSize.height / scale
        let x = clamp(state.center.x * sourceSize.width - width / 2, lower: 0, upper: sourceSize.width - width)
        let y = clamp(state.center.y * sourceSize.height - height / 2, lower: 0, upper: sourceSize.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// `center` moved inwards just enough that a view at `scale` stays inside the frame (normalized coordinates).
    static func clampedCenter(_ center: CGPoint, scale: Double) -> CGPoint {
        let half = 0.5 / (scale.isFinite ? max(scale, 1) : 1)
        return CGPoint(x: clamp(center.x, lower: half, upper: 1 - half), y: clamp(center.y, lower: half, upper: 1 - half))
    }

    /// The Core Image transform (bottom-left origin) that maps `crop` (top-left origin, in the pixels of a frame of
    /// `sourceSize`) onto an output of `outputSize`, filling it exactly. Width and height are scaled separately, so
    /// an output whose aspect ratio differs by a rounding pixel still has no border.
    static func transform(crop: CGRect, sourceSize: CGSize, outputSize: CGSize) -> CGAffineTransform {
        guard crop.width > 0, crop.height > 0 else { return .identity }
        let bottom = sourceSize.height - crop.maxY
        return CGAffineTransform(translationX: -crop.minX, y: -bottom)
            .concatenating(CGAffineTransform(scaleX: outputSize.width / crop.width, y: outputSize.height / crop.height))
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return max(lower, min(value, max(upper, lower)))
    }
}
