import CoreGraphics
import Foundation
import OrielCore
import os
import SharedUI

/// The images of one step sequence while it is captured and edited. Each new image gets its file at once and is
/// written in the background, in order; until it is on disk the image stays in memory, so it is never missing.
/// Afterwards only its thumbnail is kept in memory, which keeps a long sequence of Retina captures small.
final class StepImages {
    let store: StepImageStore
    /// Called on the main actor when an image's thumbnail is ready.
    var onThumbnail: ((URL) -> Void)?
    private(set) var thumbnails: [URL: CGImage] = [:]
    private var pending: [URL: CGImage] = [:]
    private var writing: Task<Void, Never>?
    private let log = Log.logger("capture")

    init(store: StepImageStore = .temporary()) {
        self.store = store
    }

    /// Keeps `image` and returns the file it is written to.
    func add(_ image: CGImage, scale: CGFloat) -> URL {
        let url = store.newImageURL()
        pending[url] = image
        let previous = writing
        let store = store
        writing = Task { [weak self] in
            await previous?.value
            do {
                let thumbnail = try await store.write(image, scale: scale, to: url)
                self?.written(url, thumbnail: thumbnail)
            } catch {
                self?.failed(url, error: error)
            }
        }
        return url
    }

    /// The full image: from memory while it is being written, else read from disk off the main thread.
    func image(at url: URL) async -> CGImage? {
        if let image = pending[url] {
            return image
        }
        return await Task.detached(priority: .userInitiated) { ImageFile.load(url) }.value
    }

    /// Waits until every image so far is on disk.
    func flush() async {
        await writing?.value
    }

    /// Deletes every image, once the ones being written are done.
    func discard() {
        let previous = writing
        let store = store
        pending = [:]
        thumbnails = [:]
        writing = Task {
            await previous?.value
            await store.removeAll()
        }
    }

    private func written(_ url: URL, thumbnail: CGImage?) {
        pending[url] = nil
        if let thumbnail {
            thumbnails[url] = thumbnail
        }
        onThumbnail?(url)
    }

    /// The disk is full or gone: the image stays in memory, so the sequence still has it.
    private func failed(_ url: URL, error: any Error) {
        log.error("A step could not be saved: \(error.localizedDescription, privacy: .private)")
        if let image = pending[url] {
            thumbnails[url] = ImageEncoding.thumbnail(of: image, maxPixels: StepImageStore.thumbnailPixels)
        }
        onThumbnail?(url)
    }
}
