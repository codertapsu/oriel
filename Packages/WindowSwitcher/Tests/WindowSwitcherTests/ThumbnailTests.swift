import CoreGraphics
import Testing
@testable import WindowSwitcher

/// Thumbnails (PLAN §7.1.7): an LRU cache capped in bytes, at most four captures in flight, cached images
/// first, previews released when the panel closes.
struct ThumbnailTests {
    private func image(_ side: Int) throws -> CGImage {
        try #require(TestImage.make(width: side, height: side))
    }

    @Test func theCacheEvictsTheLeastRecentlyUsedPastItsLimit() throws {
        let tile = try image(32)
        let cost = ThumbnailCache.cost(of: tile)
        var cache = ThumbnailCache(limit: cost * 3)
        cache.insert(tile, for: 1, session: 1)
        cache.insert(tile, for: 2, session: 1)
        cache.insert(tile, for: 3, session: 1)
        _ = cache.entry(for: 1)
        cache.insert(tile, for: 4, session: 1)
        #expect(cache.windowIDs == [1, 3, 4])
        #expect(cache.totalCost == cost * 3)
    }

    @Test func replacingAnEntryKeepsTheCostRight() throws {
        var cache = ThumbnailCache(limit: 1 << 20)
        try cache.insert(image(16), for: 1, session: 1)
        try cache.insert(image(64), for: 1, session: 2)
        #expect(cache.count == 1)
        #expect(try cache.totalCost == ThumbnailCache.cost(of: image(64)))
        #expect(cache.entry(for: 1)?.session == 2)
    }

    @Test func anImageLargerThanTheWholeCacheIsNotKept() throws {
        var cache = ThumbnailCache(limit: 100)
        try cache.insert(image(64), for: 1, session: 1)
        #expect(cache.count == 0 && cache.totalCost == 0)
    }

    @Test func memoryPressureKeepsOnlyTheVisibleTiles() throws {
        var cache = ThumbnailCache(limit: 1 << 20)
        for id: UInt32 in 1 ... 5 {
            try cache.insert(image(8), for: id, session: 1)
        }
        cache.purge(keeping: [2, 4])
        #expect(cache.windowIDs == [2, 4])
        cache.purge(keeping: [])
        #expect(cache.count == 0 && cache.totalCost == 0)
    }

    @Test func theDefaultCapIs48Megabytes() {
        #expect(ThumbnailService.cacheLimit == 48 * 1024 * 1024)
    }

    @Test func atMostFourCapturesRunAtOnceAndAllArrive() async {
        let capturer = FakeCapturer()
        let service = ThumbnailService(capturer: capturer)
        await service.beginSession(windowIDs: Set(1 ... 12))
        let requests = (1 ... 12).map { ThumbnailRequest(windowID: UInt32($0), pixelSize: CGSize(width: 40, height: 30)) }
        var delivered: [UInt32] = []
        for await result in await service.thumbnails(for: requests) {
            #expect(result.isFresh)
            delivered.append(result.windowID)
        }
        #expect(Set(delivered) == Set(1 ... 12))
        #expect(await capturer.maximumInFlight <= ThumbnailService.maximumInFlight)
        #expect(await capturer.maximumInFlight > 1)
        // Requests are started in order, so visible tiles (first) are captured first.
        #expect(await Array(capturer.captured.prefix(4)).sorted() == [1, 2, 3, 4])
        #expect(await capturer.prepared == [Set(1 ... 12)])
    }

    @Test func cachedThumbnailsComeFirstAndAreOnlyRecapturedInANewSession() async {
        let capturer = FakeCapturer()
        let service = ThumbnailService(capturer: capturer)
        let requests = [ThumbnailRequest(windowID: 7, pixelSize: CGSize(width: 40, height: 30))]
        await service.beginSession(windowIDs: [7])
        for await _ in await service.thumbnails(for: requests) {}
        // Same session: the cached image is fresh, nothing is captured.
        var results: [ThumbnailResult] = []
        for await result in await service.thumbnails(for: requests) {
            results.append(result)
        }
        #expect(results.map(\.isFresh) == [true])
        #expect(await capturer.captured == [7])
        // Next session: the cached one arrives stale, then a fresh capture.
        await service.beginSession(windowIDs: [7])
        results = []
        for await result in await service.thumbnails(for: requests) {
            results.append(result)
        }
        #expect(results.map(\.isFresh) == [false, true])
        #expect(await capturer.captured == [7, 7])
    }

    @Test func windowsThatCannotBeCapturedKeepTheirStaleImage() async {
        let capturer = FakeCapturer()
        let service = ThumbnailService(capturer: capturer)
        let requests = [ThumbnailRequest(windowID: 3, pixelSize: CGSize(width: 40, height: 30))]
        await service.beginSession(windowIDs: [3])
        for await _ in await service.thumbnails(for: requests) {}
        await capturer.setFailing([3])
        await service.beginSession(windowIDs: [3])
        var results: [ThumbnailResult] = []
        for await result in await service.thumbnails(for: requests) {
            results.append(result)
        }
        #expect(results.map(\.isFresh) == [false])
        #expect(await service.cachedThumbnail(for: 3)?.isFresh == false)
    }

    @Test func previewsAreKeptForTheSessionAndReleasedAfterIt() async {
        let capturer = FakeCapturer()
        let service = ThumbnailService(capturer: capturer)
        let size = CGSize(width: 120, height: 80)
        #expect(await service.preview(for: 5, pixelSize: size)?.width == 120)
        _ = await service.preview(for: 5, pixelSize: size)
        #expect(await capturer.captured == [5])
        await service.endSession()
        _ = await service.preview(for: 5, pixelSize: size)
        #expect(await capturer.captured == [5, 5])
    }

    @Test func requestsAskForTheWindowsAspectInsideTheTile() {
        #expect(ThumbnailRequest.fittedSize(window: CGSize(width: 1600, height: 900), in: CGSize(width: 400, height: 250)) == CGSize(
            width: 400,
            height: 225
        ))
        #expect(ThumbnailRequest.fittedSize(window: CGSize(width: 600, height: 1200), in: CGSize(width: 400, height: 250)) == CGSize(
            width: 125,
            height: 250
        ))
        #expect(ThumbnailRequest.fittedSize(window: .zero, in: CGSize(width: 400, height: 250)) == CGSize(width: 400, height: 250))
    }
}
