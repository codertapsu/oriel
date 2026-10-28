import CoreGraphics
@testable import Recording
import Testing

struct CaptureGeometryTests {
    /// A 14" MacBook Pro at its default scaled resolution: 1512 × 982 points, 3024 × 1964 pixels.
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func recordsAWholeDisplayAtItsNativeSize() throws {
        let geometry = try #require(CaptureGeometry(area: nil, displayFrame: laptop, scale: 2))
        #expect(geometry.sourceRect == laptop)
        #expect(geometry.captureRect == laptop)
        #expect(geometry.pixelWidth == 3024)
        #expect(geometry.pixelHeight == 1964)
        #expect(geometry.coversDisplay)
    }

    @Test func alignsARegionToWholePixels() throws {
        let area = CGRect(x: 100.3, y: 50.2, width: 400.1, height: 300.6)
        let geometry = try #require(CaptureGeometry(area: area, displayFrame: laptop, scale: 2))
        // Rounded outward to pixels (200…1001 × 100…702), then trimmed to even sizes.
        #expect(geometry.pixelWidth == 800)
        #expect(geometry.pixelHeight == 602)
        #expect(geometry.sourceRect == CGRect(x: 100, y: 50, width: 400, height: 301))
        #expect(!geometry.coversDisplay)
    }

    @Test func makesOddPixelSizesEven() throws {
        let geometry = try #require(CaptureGeometry(area: CGRect(x: 0, y: 0, width: 101, height: 75), displayFrame: laptop, scale: 1))
        #expect(geometry.pixelWidth == 100)
        #expect(geometry.pixelHeight == 74)
        #expect(geometry.sourceRect.size == CGSize(width: 100, height: 74))
    }

    @Test func usesDisplayLocalPointsForASecondaryDisplay() throws {
        // A 1× display to the left of the main one and higher up: negative x and y in global coordinates.
        let external = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let area = CGRect(x: -1000, y: 0, width: 640, height: 480)
        let geometry = try #require(CaptureGeometry(area: area, displayFrame: external, scale: 1))
        #expect(geometry.sourceRect == CGRect(x: 920, y: 200, width: 640, height: 480))
        #expect(geometry.captureRect == area)
    }

    @Test func clipsToTheDisplay() throws {
        let area = CGRect(x: 1400, y: 900, width: 400, height: 400)
        let geometry = try #require(CaptureGeometry(area: area, displayFrame: laptop, scale: 2))
        #expect(geometry.captureRect == CGRect(x: 1400, y: 900, width: 112, height: 82))
    }

    @Test func rejectsAreasThatAreEmptyOrOffTheDisplay() {
        #expect(CaptureGeometry(area: CGRect(x: 5000, y: 0, width: 100, height: 100), displayFrame: laptop, scale: 2) == nil)
        #expect(CaptureGeometry(area: CGRect(x: 10, y: 10, width: 1, height: 1), displayFrame: laptop, scale: 1) == nil)
        #expect(CaptureGeometry(area: .zero, displayFrame: laptop, scale: 2) == nil)
    }

    @Test func fitsPresetsWithoutChangingTheAspectRatio() throws {
        let geometry = try #require(CaptureGeometry(area: nil, displayFrame: laptop, scale: 2))
        let standard = geometry.outputSize(resolution: RecordingPreset.standard.resolution, codec: .h264)
        #expect(standard.width == 1662 && standard.height == 1080)
        let small = geometry.outputSize(resolution: RecordingPreset.small.resolution, codec: .h264)
        #expect(small.width == 1108 && small.height == 720)
        let high = geometry.outputSize(resolution: RecordingPreset.high.resolution, codec: .hevc)
        #expect(high.width == 3024 && high.height == 1964)
    }

    @Test func neverScalesUp() throws {
        let geometry = try #require(CaptureGeometry(area: CGRect(x: 0, y: 0, width: 400, height: 300), displayFrame: laptop, scale: 2))
        let size = geometry.outputSize(resolution: RecordingPreset.standard.resolution, codec: .h264)
        #expect(size.width == 800 && size.height == 600)
    }

    @Test func fitsPortraitDisplaysByTheirLongEdge() throws {
        let portrait = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let geometry = try #require(CaptureGeometry(area: nil, displayFrame: portrait, scale: 2))
        let size = geometry.outputSize(resolution: RecordingPreset.standard.resolution, codec: .h264)
        #expect(size.width == 1080 && size.height == 1920)
    }

    @Test func keepsH264WithinTheEncoderLimit() throws {
        // A 6K display at full resolution: HEVC keeps it, H.264 has to scale it to 4096 × 2304.
        let sixK = CGRect(x: 0, y: 0, width: 3008, height: 1692)
        let geometry = try #require(CaptureGeometry(area: nil, displayFrame: sixK, scale: 2))
        let hevc = geometry.outputSize(resolution: .native, codec: .hevc)
        #expect(hevc.width == 6016 && hevc.height == 3384)
        let h264 = geometry.outputSize(resolution: .native, codec: .h264)
        #expect(h264.width == 4096 && h264.height == 2304)
    }
}
