import CoreGraphics

/// What a video editor export writes (PLAN §17): the container, the codec, the frame size and, for a GIF, its
/// width and frame rate. Pure.
nonisolated struct VideoExportOptions: Equatable, Sendable {
    /// Sound is encoded as stereo AAC at this many bits per second.
    static let audioBitRate = 160_000

    var format: VideoExportFormat = .mp4
    var codec: VideoCodec = .h264
    var size: VideoExportSize = .original
    var gif = GIFExportOptions()

    /// The average bit rate for screen content: about 7.5 Mbit/s for 1080p30 H.264 (PLAN §7.4's Standard
    /// preset), HEVC at roughly 60 % of that, between 1 and 80 Mbit/s.
    static func videoBitRate(width: Int, height: Int, frameRate: Double, codec: VideoCodec) -> Int {
        let bitsPerPixel = codec == .hevc ? 0.072 : 0.12
        let rate = min(max(frameRate.isFinite ? frameRate : 30, 24), 60)
        let bits = Double(max(width, 2) * max(height, 2)) * rate * bitsPerPixel
        return Int(min(max(bits, 1_000_000), 80_000_000))
    }
}
