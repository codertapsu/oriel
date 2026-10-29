import CoreGraphics

/// A picture behind the screenshot: the desktop picture, or an image the user chose. It covers the canvas without
/// distortion and can be blurred.
nonisolated struct BackgroundImage: Codable, Sendable, Hashable {
    enum Source: String, Codable, Sendable {
        case desktopPicture
        case file
    }

    var asset: ImageAsset
    var source: Source
    /// Blur radius, in points; 0 leaves the picture sharp.
    var blur: CGFloat

    init(asset: ImageAsset, source: Source, blur: CGFloat = 0) {
        self.asset = asset
        self.source = source
        self.blur = min(max(blur, 0), Self.blurRange.upperBound)
    }

    static let blurRange: ClosedRange<CGFloat> = 0 ... 60
}
