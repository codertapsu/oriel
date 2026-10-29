import Foundation

/// Why the video editor could not open, read or export a movie.
nonisolated enum VideoEditorError: LocalizedError, Equatable, Sendable {
    /// The file has no video track.
    case noVideo
    /// The file is not a movie AVFoundation can read.
    case unreadable
    /// The kept part is shorter than `VideoEdit.minimumLength`.
    case tooShort
    /// The export would replace the movie being edited.
    case replacesSource
    /// No frame could be read at the playhead.
    case noFrame
    /// Writing the export failed.
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideo: "The file has no video."
        case .unreadable: "The file is not a movie Oriel can open."
        case .tooShort: "The part to export is too short."
        case .replacesSource: "Choose another name: the movie being edited cannot be replaced."
        case .noFrame: "The frame could not be read."
        case let .exportFailed(message): "The movie could not be exported: \(message)"
        }
    }
}
