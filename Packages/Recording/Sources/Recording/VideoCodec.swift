import AVFoundation

/// The video codec a recording is encoded with.
public nonisolated enum VideoCodec: String, CaseIterable, Codable, Sendable, Identifiable {
    /// H.264: plays everywhere.
    case h264
    /// HEVC (H.265): about half the size at the same quality.
    case hevc

    /// The raw value, for SwiftUI lists.
    public var id: String {
        rawValue
    }

    /// The name settings show.
    public var displayName: String {
        switch self {
        case .h264: "H.264"
        case .hevc: "HEVC"
        }
    }

    var avCodecType: AVVideoCodecType {
        switch self {
        case .h264: .h264
        case .hevc: .hevc
        }
    }

    /// The largest frame the hardware encoders accept, as long edge × short edge in pixels. H.264 tops out at
    /// 4096 × 2304, so a native-resolution H.264 recording of a 5K or 6K display is scaled to fit.
    var maximumFrame: (long: Int, short: Int) {
        switch self {
        case .h264: (4096, 2304)
        case .hevc: (8192, 4320)
        }
    }
}
