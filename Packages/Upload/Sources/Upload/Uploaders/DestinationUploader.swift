import Foundation

/// What every kind of destination does (PLAN §7.8's `UploadDestination` protocol; the stored settings took that name).
/// `UploadService` makes one per upload or test, with the settings, secrets and session it needs; each runs off the
/// main thread.
nonisolated protocol DestinationUploader: Sendable {
    /// Sends `payload` to `path` below the destination's folder, reporting progress, and returns the link.
    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt

    /// Checks that uploads can work, without leaving anything behind, and says what it found.
    func testConnection() async throws -> String
}
