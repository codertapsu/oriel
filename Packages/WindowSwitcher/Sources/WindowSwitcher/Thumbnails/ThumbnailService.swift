import CoreGraphics

/// Tile thumbnails and full-size previews (PLAN §7.1.7). Captures happen only while the switcher is open, at
/// tile size, at most four at a time, in request order (visible tiles first); nothing runs in the background.
/// Thumbnails live in a 48 MB LRU cache; previews are released when the panel closes.
actor ThumbnailService {
    static let cacheLimit = 48 * 1024 * 1024
    static let maximumInFlight = 4

    private nonisolated struct Capture: Sendable {
        var windowID: UInt32
        var image: CGImage?
    }

    private let capturer: any WindowCapturing
    private var cache: ThumbnailCache
    private var previews: [UInt32: CGImage] = [:]
    private(set) var session = 0

    init(capturer: any WindowCapturing, cacheLimit: Int = ThumbnailService.cacheLimit) {
        self.capturer = capturer
        cache = ThumbnailCache(limit: cacheLimit)
    }

    var cachedCost: Int {
        cache.totalCost
    }

    /// The switcher opened: captures from now on are fresh, and the capturer learns about new windows.
    func beginSession(windowIDs: Set<UInt32>) async {
        session += 1
        await capturer.prepare(windowIDs: windowIDs)
    }

    /// Cached images first (stale ones flagged), then fresh captures as they complete. Cancelling the
    /// consuming task stops the captures that have not started.
    func thumbnails(for requests: [ThumbnailRequest]) -> AsyncStream<ThumbnailResult> {
        let (stream, continuation) = AsyncStream.makeStream(of: ThumbnailResult.self)
        var pending: [ThumbnailRequest] = []
        for request in requests {
            if let cached = cache.entry(for: request.windowID) {
                let isFresh = cached.session == session && Self.covers(cached.image, request.pixelSize)
                continuation.yield(ThumbnailResult(windowID: request.windowID, image: cached.image, isFresh: isFresh))
                if isFresh {
                    continue
                }
            }
            pending.append(request)
        }
        let task = Task { await self.capture(pending, into: continuation) }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    /// The cached thumbnail, for an instant (stale) preview.
    func cachedThumbnail(for windowID: UInt32) -> ThumbnailResult? {
        guard let cached = cache.entry(for: windowID) else { return nil }
        return ThumbnailResult(windowID: windowID, image: cached.image, isFresh: cached.session == session)
    }

    /// A full-resolution capture for the preview panel, kept until the panel closes.
    func preview(for windowID: UInt32, pixelSize: CGSize) async -> CGImage? {
        if let image = previews[windowID] {
            return image
        }
        guard let image = await capturer.capture(windowID: windowID, pixelSize: pixelSize) else { return nil }
        previews[windowID] = image
        return image
    }

    /// The panel closed: full-resolution previews go.
    func endSession() {
        previews.removeAll()
    }

    /// Memory pressure: keep only the visible tiles' thumbnails.
    func purge(keeping windowIDs: Set<UInt32>) {
        cache.purge(keeping: windowIDs)
        previews = previews.filter { windowIDs.contains($0.key) }
    }

    func removeAll() {
        cache.purge(keeping: [])
        previews.removeAll()
    }

    private func capture(_ requests: [ThumbnailRequest], into continuation: AsyncStream<ThumbnailResult>.Continuation) async {
        let capturer = capturer
        let session = session
        await withTaskGroup(of: Capture.self) { group in
            var queue = requests[...]
            func launchNext() {
                guard let next = queue.popFirst() else { return }
                group.addTask {
                    await Capture(windowID: next.windowID, image: capturer.capture(windowID: next.windowID, pixelSize: next.pixelSize))
                }
            }
            for _ in 0 ..< Self.maximumInFlight {
                launchNext()
            }
            while let result = await group.next() {
                if let image = result.image {
                    cache.insert(image, for: result.windowID, session: session)
                    continuation.yield(ThumbnailResult(windowID: result.windowID, image: image, isFresh: true))
                }
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                launchNext()
            }
        }
        continuation.finish()
    }

    /// Whether a cached image is at least as large as the tile now asks for.
    private static func covers(_ image: CGImage, _ size: CGSize) -> Bool {
        CGFloat(image.width) >= size.width.rounded(.down) || CGFloat(image.height) >= size.height.rounded(.down)
    }
}
