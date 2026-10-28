/// How a GIF is rendered from a finished movie (PLAN §7.4).
nonisolated struct GIFExportOptions: Sendable, Equatable {
    /// The frame rates a GIF may use. GIF delays are whole centiseconds, so the exporter spreads the rounding.
    static let frameRates = 10 ... 15
    /// The narrowest a GIF may be made.
    static let minimumWidth = 16

    /// Frames per second, within `frameRates`.
    let frameRate: Int
    /// The widest the GIF may be, in pixels. Narrower movies keep their width.
    let maxWidth: Int

    init(frameRate: Int = 10, maxWidth: Int = 800) {
        self.frameRate = min(max(frameRate, Self.frameRates.lowerBound), Self.frameRates.upperBound)
        self.maxWidth = max(maxWidth, Self.minimumWidth)
    }
}
