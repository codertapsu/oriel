import CoreGraphics
import Foundation
@testable import Recording
import Testing

@MainActor
struct ThumbnailCacheTests {
    @Test func makesThumbnailsInTheBackground() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await PatternMovie.write(to: movie, width: 640, height: 360, frameTimes: [0, 1], duration: 2)
        let cache = try await ThumbnailCache(info: MovieInfo.load(movie), height: 90)
        #expect(cache.pixelSize == CGSize(width: 160, height: 90))
        #expect(cache.image(near: 0.5, tolerance: 1) == nil)

        await withCheckedContinuation { continuation in
            var resumed = false
            cache.onUpdate = {
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }
            cache.request([0.5, 1.5], tolerance: 0.25)
        }

        let image = try #require(cache.image(near: 0.5, tolerance: 0.01))
        #expect(image.width == 160 && image.height == 90)
        #expect(cache.image(near: 1.52, tolerance: 0.05) != nil)
        #expect(cache.image(near: 5, tolerance: 0.5) == nil)
    }
}
