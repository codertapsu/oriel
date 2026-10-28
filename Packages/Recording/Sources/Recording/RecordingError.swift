import AVFoundation
import Foundation
import ScreenCaptureKit

/// Why a recording could not start, continue or be saved. A missing Screen Recording grant is reported as
/// `OrielError.permissionMissing(.screenRecording)` instead.
public nonisolated enum RecordingError: LocalizedError, Sendable, Equatable {
    /// `start` was called while a recording was already running.
    case alreadyRecording
    /// The display to record is not connected any more.
    case displayNotFound
    /// The window to record is closed, minimized or on another Space.
    case windowNotFound
    /// The area to record is smaller than 2 × 2 pixels or outside its display.
    case emptyArea
    /// The disk holding the recordings folder is (nearly) full.
    case insufficientStorage
    /// Capture stopped before any frame was written.
    case nothingRecorded
    /// ScreenCaptureKit refused or stopped the stream.
    case streamFailed(String)
    /// Joining, trimming or converting the movie failed.
    case exportFailed(String)

    /// One sentence for an alert or a toast.
    public var errorDescription: String? {
        switch self {
        case .alreadyRecording: "A recording is already running."
        case .displayNotFound: "The display to record is not connected."
        case .windowNotFound: "The window to record is not on screen."
        case .emptyArea: "The area to record is empty."
        case .insufficientStorage: "There is not enough free disk space to record."
        case .nothingRecorded: "Nothing was recorded."
        case let .streamFailed(message): "Recording failed: \(message)"
        case let .exportFailed(message): "The movie could not be saved: \(message)"
        }
    }

    /// Maps a ScreenCaptureKit, AVFoundation or file-system error to a recording error.
    static func from(_ error: any Error) -> RecordingError {
        if let error = error as? RecordingError {
            return error
        }
        if isOutOfSpace(error) {
            return .insufficientStorage
        }
        return .streamFailed(error.localizedDescription)
    }

    /// Whether the user ended the capture, from the system's screen-sharing menu or by revoking access. Such a stop
    /// still saves what was recorded.
    static func isUserStop(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userStopped.rawValue
    }

    static func isOutOfSpace(_ error: any Error) -> Bool {
        let error = error as NSError
        let isFull = switch error.domain {
        case SCStreamErrorDomain: isInsufficientStorage(code: error.code)
        case AVFoundationErrorDomain: error.code == AVError.Code.diskFull.rawValue
        case NSCocoaErrorDomain: error.code == NSFileWriteOutOfSpaceError
        case NSPOSIXErrorDomain: error.code == Int(ENOSPC)
        default: false
        }
        if isFull {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isOutOfSpace(underlying)
        }
        return false
    }

    /// `SCStreamErrorInsufficientStorage`, which ScreenCaptureKit reports from macOS 27 on (S8).
    private static func isInsufficientStorage(code: Int) -> Bool {
        guard #available(macOS 27, *) else { return false }
        return code == SCStreamError.Code.insufficientStorage.rawValue
    }
}
