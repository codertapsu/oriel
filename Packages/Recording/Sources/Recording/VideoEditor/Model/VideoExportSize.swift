import CoreGraphics

/// How large an exported movie's frames are (PLAN §17): as recorded, or scaled down to fit 1080p or 720p, keeping
/// the aspect ratio. Never scaled up. Pure.
nonisolated enum VideoExportSize: String, CaseIterable, Codable, Sendable {
    case original
    case fullHD
    case hd

    var title: String {
        switch self {
        case .original: "Original"
        case .fullHD: "1080p"
        case .hd: "720p"
        }
    }

    /// The long and short edge the frame must fit, or nil for no limit.
    private var limit: (long: Int, short: Int)? {
        switch self {
        case .original: nil
        case .fullHD: (1920, 1080)
        case .hd: (1280, 720)
        }
    }

    /// The exported frame size for a movie whose frames are `source` pixels, also within `codec`'s largest frame:
    /// rounded down to even numbers, which the H.264 and HEVC encoders need.
    func pixelSize(for source: CGSize, codec: VideoCodec) -> CGSize {
        guard source.width >= 2, source.height >= 2 else { return CGSize(width: 2, height: 2) }
        let long = Double(max(source.width, source.height))
        let short = Double(min(source.width, source.height))
        var factor = 1.0
        if let limit {
            factor = min(factor, Double(limit.long) / long, Double(limit.short) / short)
        }
        let maximum = codec.maximumFrame
        factor = min(factor, Double(maximum.long) / long, Double(maximum.short) / short)
        return CGSize(width: Self.even(Double(source.width) * factor), height: Self.even(Double(source.height) * factor))
    }

    /// Whether the choice gives a frame of its own: 1080p of a 720p recording is the original, so it is not offered.
    func isDistinct(for source: CGSize, codec: VideoCodec) -> Bool {
        switch self {
        case .original: true
        case .fullHD: pixelSize(for: source, codec: codec) != VideoExportSize.original.pixelSize(for: source, codec: codec)
        case .hd: pixelSize(for: source, codec: codec) != VideoExportSize.fullHD.pixelSize(for: source, codec: codec)
        }
    }

    /// Rounds down to an even number of at least 2. The epsilon keeps 1079.9999… from becoming 1078.
    private static func even(_ value: Double) -> Int {
        let whole = Int((value + 0.0001).rounded(.down))
        return max(2, whole - whole % 2)
    }
}
