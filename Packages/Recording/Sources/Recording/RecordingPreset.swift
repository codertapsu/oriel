/// A quality preset (PLAN §7.4). The frame rate and codec are defaults that settings can override.
///
/// `SCRecordingOutputConfiguration` has no bitrate property, so the encoder picks the bitrate; Standard's
/// "≈ 8 Mbps" in the plan is the typical result for 1080p30 H.264 screen content, not a setting.
public nonisolated enum RecordingPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 1080p-equivalent, 30 fps, H.264.
    case standard
    /// Native resolution, 60 fps, HEVC.
    case high
    /// 720p, 24 fps, H.264.
    case small

    /// How large the output frame may be.
    enum Resolution: Equatable, Sendable {
        /// Every captured pixel.
        case native
        /// Scaled down (never up) so the long edge fits `long` and the short edge fits `short`.
        case fit(long: Int, short: Int)
    }

    /// The raw value, for SwiftUI lists.
    public var id: String {
        rawValue
    }

    /// The name settings show.
    public var displayName: String {
        switch self {
        case .standard: "Standard (1080p, 30 fps, H.264)"
        case .high: "High (native, 60 fps, HEVC)"
        case .small: "Small (720p, 24 fps, H.264)"
        }
    }

    /// The frame rate used unless settings override it.
    public var frameRate: Int {
        switch self {
        case .standard: 30
        case .high: 60
        case .small: 24
        }
    }

    /// The codec used unless settings override it.
    public var codec: VideoCodec {
        switch self {
        case .standard, .small: .h264
        case .high: .hevc
        }
    }

    var resolution: Resolution {
        switch self {
        case .standard: .fit(long: 1920, short: 1080)
        case .high: .native
        case .small: .fit(long: 1280, short: 720)
        }
    }
}
