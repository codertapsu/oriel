import CoreGraphics
import Foundation

/// Why a capture failed. Headless captures (the CLI) throw these; interactive captures explain them on screen.
public nonisolated enum CaptureError: LocalizedError, Sendable, Equatable {
    /// Screen & System Audio Recording is not granted.
    case screenRecordingDenied
    /// No display matches, or ScreenCaptureKit lists none.
    case displayNotFound
    /// The window is gone, or ScreenCaptureKit cannot capture it.
    case windowNotFound(CGWindowID)
    /// The rectangle is empty or lies outside every display.
    case emptyArea
    /// ScreenCaptureKit, ImageIO or Core Graphics failed.
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            "Oriel needs the Screen & System Audio Recording permission to capture the screen."
        case .displayNotFound:
            "There is no display to capture."
        case let .windowNotFound(id):
            "Window \(id) is not available for capture."
        case .emptyArea:
            "The area is empty or not on any display."
        case let .failed(message):
            message
        }
    }
}
