import AVFoundation
import UniformTypeIdentifiers

/// The kinds of file the video editor exports (PLAN §17).
nonisolated enum VideoExportFormat: String, CaseIterable, Codable, Sendable {
    /// MPEG-4: plays everywhere; keeps the chapters.
    case mp4
    /// QuickTime movie; keeps the chapters.
    case mov
    /// A looping animation without sound, at most `GIFFramePlan.maximumFrameCount` frames.
    case gif

    /// What the export panel shows.
    var title: String {
        switch self {
        case .mp4: "MPEG-4 Movie"
        case .mov: "QuickTime Movie"
        case .gif: "Animated GIF"
        }
    }

    var fileExtension: String {
        rawValue
    }

    var contentType: UTType {
        switch self {
        case .mp4: .mpeg4Movie
        case .mov: .quickTimeMovie
        case .gif: .gif
        }
    }

    /// The container AVAssetWriter writes; nil for a GIF, which ImageIO writes.
    var fileType: AVFileType? {
        switch self {
        case .mp4: .mp4
        case .mov: .mov
        case .gif: nil
        }
    }

    /// Whether the file can carry a chapter track and sound.
    var isMovie: Bool {
        self != .gif
    }
}
