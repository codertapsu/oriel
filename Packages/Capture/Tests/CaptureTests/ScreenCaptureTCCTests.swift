@testable import Capture
import CoreGraphics
import OrielTestSupport
import Testing

/// Runs only with ORIEL_TCC_TESTS=1 on a Mac whose test runner holds Screen Recording. Read-only: one in-memory capture
/// of one display, no windows, no events, no files.
@MainActor
struct ScreenCaptureTCCTests {
    @Test(.requiresTCC)
    func displayCapturesHaveNativePixelSize() async throws {
        let cache = ShareableContentCache()
        let content = try await cache.current(refresh: true)
        let display = try #require(content.displays.first)
        let frozen = try await ScreenshotEngine().capture(display, excluding: [], options: ScreenshotEngine.Options())
        #expect(frozen.display.frame == display.frame)
        #expect(frozen.display.scale >= 1)
        #expect(frozen.image.width == Int((CGFloat(display.width) * frozen.display.scale).rounded()))
        #expect(frozen.image.height == Int((CGFloat(display.height) * frozen.display.scale).rounded()))
        #expect(frozen.hdrImage == nil)
        // The cache answers again without another fetch.
        let cached = try await cache.current()
        #expect(cached === content)
    }
}
