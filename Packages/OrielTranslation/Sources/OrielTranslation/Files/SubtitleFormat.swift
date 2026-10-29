/// The two subtitle formats.
enum SubtitleFormat: String, Hashable, Sendable {
    case srt
    case vtt

    var title: String {
        switch self {
        case .srt: "SRT"
        case .vtt: "WebVTT"
        }
    }
}
