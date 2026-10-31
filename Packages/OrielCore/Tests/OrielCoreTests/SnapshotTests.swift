import CoreGraphics
import Foundation
import OrielTestSupport
import Testing

/// The image-diff helper itself (PLAN §14.4): tolerance per channel, sizes, the references' place and the failure's
/// diff image.
struct SnapshotTests {
    /// A gray image with one pixel set apart.
    private func image(
        width: Int = 4,
        height: Int = 3,
        gray: CGFloat = 0.5,
        odd: (x: Int, y: Int, value: CGFloat)? = nil
    ) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if let odd {
            context.setFillColor(CGColor(srgbRed: odd.value, green: odd.value, blue: odd.value, alpha: 1))
            context.fill(CGRect(x: odd.x, y: odd.y, width: 1, height: 1))
        }
        return try #require(context.makeImage())
    }

    @Test func identicalImagesDoNotDiffer() throws {
        let difference = try Snapshot.compare(image(), image(), tolerance: 0)
        #expect(difference.sizesMatch && difference.differingPixels == 0 && difference.largestChannelDifference == 0)
        #expect(difference.pixelCount == 12)
    }

    @Test func aPixelDiffersOnlyBeyondTheTolerance() throws {
        // 0.5 → 128, 0.52 → 133: five levels apart.
        let nudged = try image(odd: (x: 1, y: 1, value: 0.52))
        let within = try Snapshot.compare(nudged, image(), tolerance: 5)
        #expect(within.differingPixels == 0 && within.largestChannelDifference == 5)
        let beyond = try Snapshot.compare(nudged, image(), tolerance: 4)
        #expect(beyond.differingPixels == 1 && abs(beyond.fraction - 1.0 / 12) < 1e-9)
    }

    @Test func imagesOfAnotherSizeDifferEverywhere() throws {
        let difference = try Snapshot.compare(image(width: 5), image(), tolerance: 255)
        #expect(!difference.sizesMatch && difference.fraction == 1)
    }

    @Test func theDiffFadesTheReferenceAndMarksTheDifferingPixelsInRed() throws {
        let marked = try #require(try Snapshot.diffImage(image(odd: (x: 0, y: 0, value: 1)), image(), tolerance: 2))
        // Gray 128 fades to 128 / 4 + 191 = 223; the changed pixel is red, where it was drawn.
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 4, height: 3, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 223.0 / 255, green: 223.0 / 255, blue: 223.0 / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let expected = try #require(context.makeImage())
        #expect(Snapshot.compare(marked, expected, tolerance: 1).differingPixels == 0)
    }

    @Test func referencesLiveInTheirPackagesFixturesAndAreNamedForTheOS() {
        let url = Snapshot.referenceURL("glass", filePath: "/repo/Packages/SharedUI/Tests/SharedUITests/GlassTests.swift")
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        #expect(url.path == "/repo/Packages/SharedUI/Tests/Fixtures/snapshots/glass@macOS\(major).png")
    }

    @Test func imagesRoundTripThroughPNG() throws {
        let original = try image(odd: (x: 2, y: 1, value: 0.9))
        let url = FileManager.default.temporaryDirectory.appending(path: "oriel-snapshot-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Snapshot.write(original, to: url)
        let loaded = try #require(Snapshot.load(url))
        #expect(Snapshot.compare(loaded, original, tolerance: 0).differingPixels == 0)
    }
}
