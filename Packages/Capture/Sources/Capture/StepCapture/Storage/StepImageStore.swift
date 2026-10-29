import CoreGraphics
import Foundation
import OrielCore
import os

/// A step sequence's images on disk: one PNG per image in a folder of its own under the temporary directory, which
/// is deleted when the sequence is discarded (and by macOS, should Oriel quit first). An actor, so encoding and file
/// IO stay off the main thread.
actor StepImageStore {
    /// The thumbnails in the sequence window are at most this many pixels on their long side.
    static let thumbnailPixels = 480

    nonisolated let directory: URL
    private let log = Log.logger("capture")

    init(directory: URL) {
        self.directory = directory
    }

    /// A store with a new, empty folder of its own.
    static func temporary() -> StepImageStore {
        let base = FileManager.default.temporaryDirectory.appending(path: "Oriel Step Capture", directoryHint: .isDirectory)
        return StepImageStore(directory: base.appending(path: UUID().uuidString, directoryHint: .isDirectory))
    }

    /// Where a new image goes; nothing is written yet.
    nonisolated func newImageURL() -> URL {
        directory.appending(path: "\(UUID().uuidString).png")
    }

    /// Writes `image` as PNG (with its scale as DPI) to `url` and returns its thumbnail.
    func write(_ image: CGImage, scale: CGFloat, to url: URL) throws -> CGImage? {
        try AppPaths.ensureDirectory(directory)
        guard let png = ImageEncoding.data(for: image, format: .png, scale: scale) else {
            throw CaptureError.failed("A step could not be encoded.")
        }
        try png.write(to: url, options: .atomic)
        return ImageEncoding.thumbnail(of: image, maxPixels: Self.thumbnailPixels)
    }

    /// Deletes the folder and everything in it.
    func removeAll() {
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        } catch {
            log.error("Step Capture's images could not be deleted: \(error.localizedDescription, privacy: .private)")
        }
    }
}
