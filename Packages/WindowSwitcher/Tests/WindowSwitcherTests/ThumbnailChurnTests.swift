import CoreGraphics
import Testing
@testable import WindowSwitcher

/// The thumbnail cache stays at or under 48 MB decoded through many sessions in which windows come and go, and what it
/// evicts is freed (PLAN §9, §14.4 "thumbnail cache churn"): the images still in memory are the ones it holds.
struct ThumbnailChurnTests {
    /// A 220 pt tile's image at 2×: 416 × 260 px, about 0.41 MB, so 150 windows (62 MB) overflow the cache.
    private static let pixelSize = CGSize(width: 416, height: 260)
    private static let imageCost = 416 * 4 * 260

    @Test func theCacheStaysUnderItsCapAndFreesWhatItEvicts() async {
        let capturer = CountingCapturer()
        let service = ThumbnailService(capturer: capturer)
        for session in 0 ..< 20 {
            // Each session, 10 windows have closed and 10 new ones opened.
            let windows = (UInt32(session * 10) ..< UInt32(session * 10 + 150)).map { $0 + 1 }
            await service.beginSession(windowIDs: Set(windows))
            var delivered = 0
            for await _ in await service.thumbnails(for: windows.map { ThumbnailRequest(windowID: $0, pixelSize: Self.pixelSize) }) {
                delivered += 1
            }
            #expect(delivered >= windows.count)
            await service.endSession()
            let cost = await service.cachedCost
            #expect(cost <= ThumbnailService.cacheLimit, "\(cost) bytes after session \(session)")
            #expect(cost > ThumbnailService.cacheLimit - Self.imageCost, "the cache filled up")
            #expect(capturer.liveCount == cost / Self.imageCost, "images alive besides the cache's after session \(session)")
        }
        let cached = await service.cachedCost
        print("thumbnail churn: \(cached / 1_048_576) MB cached, \(capturer.liveCount) images alive")
        await service.removeAll()
        #expect(capturer.liveCount == 0)
    }
}
