import CoreGraphics
import OrielCore

/// Which pixels of a display a recording reads and how large its frames are (PLAN §7.2 item 5, §7.4). Pure, so it
/// is tested with synthetic displays.
nonisolated struct CaptureGeometry: Equatable, Sendable {
    /// The display's frame in global CoreGraphics points.
    let displayFrame: CGRect
    /// Pixels per point on that display.
    let scale: CGFloat
    /// The recorded area in global CoreGraphics points: aligned to whole pixels, clipped to the display, and an even
    /// number of pixels wide and high, because the H.264 and HEVC encoders need even frame sizes.
    let captureRect: CGRect
    /// `captureRect` in the display's own points, which is what `SCStreamConfiguration.sourceRect` takes.
    let sourceRect: CGRect
    /// The width of `captureRect` in pixels.
    let pixelWidth: Int
    /// The height of `captureRect` in pixels.
    let pixelHeight: Int

    /// The area of a display to record; nil records the whole display. Returns nil when what is left after clipping
    /// is smaller than 2 × 2 pixels.
    init?(area: CGRect?, displayFrame: CGRect, scale: CGFloat) {
        let scale = scale > 0 ? scale : 1
        let pixels = ScreenGeometry.pixelRect(for: area ?? displayFrame, displayBounds: displayFrame, scale: scale)
        var width = Int(pixels.width)
        var height = Int(pixels.height)
        width -= width % 2
        height -= height % 2
        guard width >= 2, height >= 2 else { return nil }
        let source = CGRect(
            x: pixels.minX / scale,
            y: pixels.minY / scale,
            width: CGFloat(width) / scale,
            height: CGFloat(height) / scale
        )
        self.displayFrame = displayFrame
        self.scale = scale
        sourceRect = source
        captureRect = source.offsetBy(dx: displayFrame.minX, dy: displayFrame.minY)
        pixelWidth = width
        pixelHeight = height
    }

    /// Whether the whole display is recorded.
    var coversDisplay: Bool {
        captureRect.size == displayFrame.size
    }

    /// The frame size a recording writes: the native size, scaled down to fit the preset and the codec's limits,
    /// keeping the aspect ratio, rounded down to even numbers.
    func outputSize(resolution: RecordingPreset.Resolution, codec: VideoCodec) -> (width: Int, height: Int) {
        let long = Double(max(pixelWidth, pixelHeight))
        let short = Double(min(pixelWidth, pixelHeight))
        var factor = 1.0
        if case let .fit(maxLong, maxShort) = resolution {
            factor = min(factor, Double(maxLong) / long, Double(maxShort) / short)
        }
        let limit = codec.maximumFrame
        factor = min(factor, Double(limit.long) / long, Double(limit.short) / short)
        return (Self.even(Double(pixelWidth) * factor), Self.even(Double(pixelHeight) * factor))
    }

    /// Rounds down to an even number of at least 2. The epsilon keeps 1079.9999… from becoming 1078.
    private static func even(_ value: Double) -> Int {
        let whole = Int((value + 0.0001).rounded(.down))
        return max(2, whole - whole % 2)
    }
}
