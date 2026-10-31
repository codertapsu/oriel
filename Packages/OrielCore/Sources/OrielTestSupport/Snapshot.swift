import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Image-diff tests (PLAN §14.4): a rendered image is compared with a PNG reference in the package's
/// `Tests/Fixtures/snapshots/`, channel by channel within a tolerance. References are recorded per macOS major version
/// (`name@macOS27.png`), because glass and text render differently between releases, and a test whose references were
/// recorded on another macOS is skipped (`.snapshots(_:)`). `ORIEL_RECORD_SNAPSHOTS=1` writes the references instead.
public enum Snapshot {
    /// How an image differs from its reference.
    public struct Difference: Sendable, Equatable {
        public let sizesMatch: Bool
        /// Pixels with a channel more than the tolerance off; every pixel when the sizes differ.
        public let differingPixels: Int
        public let pixelCount: Int
        /// The largest difference of any channel, 0–255.
        public let largestChannelDifference: Int

        public var fraction: Double {
            pixelCount == 0 ? 0 : Double(differingPixels) / Double(pixelCount)
        }
    }

    public static var isRecording: Bool {
        ProcessInfo.processInfo.environment["ORIEL_RECORD_SNAPSHOTS"] == "1"
    }

    /// `@macOS27` on macOS 27.
    public static var osSuffix: String {
        "@macOS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }

    /// The reference for `name` on this macOS, in the snapshots folder of the package whose test file is `filePath`.
    public static func referenceURL(_ name: String, filePath: String) -> URL {
        Fixtures.folder("snapshots", filePath: filePath).appending(path: name + osSuffix + ".png")
    }

    /// Draws `view`'s layer tree, laid out at its size, into an sRGB image `scale` times its size in points, in the
    /// view's appearance. A view outside any window is put in one that is never shown, so AppKit draws its contents
    /// (at the main display's scale). Glass is composited by the window server and is not drawn.
    @MainActor
    public static func render(_ view: NSView, scale: CGFloat = 2) -> CGImage? {
        var host: NSWindow?
        if view.window == nil, view.superview == nil {
            let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: true)
            window.contentView = view
            host = window
        }
        defer { host?.contentView = nil }
        view.layoutSubtreeIfNeeded()
        (view.window ?? host)?.displayIfNeeded()
        view.displayIfNeeded()
        let width = Int((view.bounds.width * scale).rounded())
        let height = Int((view.bounds.height * scale).rounded())
        guard let layer = view.layer, width > 0, height > 0, let context = bitmap(width: width, height: height) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        // Core Animation draws with y up; a flipped view's layers are arranged with y down.
        if view.isFlipped {
            context.translateBy(x: 0, y: view.bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.render(in: context)
        }
        return context.makeImage()
    }

    /// Compares two images pixel by pixel in sRGB, premultiplied: a pixel differs when a channel is more than
    /// `tolerance` (0–255) off.
    public static func compare(_ image: CGImage, _ reference: CGImage, tolerance: Int) -> Difference {
        let count = image.width * image.height
        guard image.width == reference.width, image.height == reference.height,
              let pixels = rgba(image), let expected = rgba(reference)
        else {
            return Difference(sizesMatch: false, differingPixels: max(count, 1), pixelCount: max(count, 1), largestChannelDifference: 255)
        }
        var differing = 0
        var largest = 0
        for pixel in 0 ..< count {
            var worst = 0
            for channel in 0 ..< 4 {
                let index = pixel * 4 + channel
                worst = max(worst, abs(Int(pixels[index]) - Int(expected[index])))
            }
            largest = max(largest, worst)
            if worst > tolerance {
                differing += 1
            }
        }
        return Difference(sizesMatch: true, differingPixels: differing, pixelCount: count, largestChannelDifference: largest)
    }

    /// Compares `image` with the reference `name`, or records it with `ORIEL_RECORD_SNAPSHOTS=1`. At most
    /// `allowedFraction` of the pixels may differ by more than `tolerance`. On a mismatch, the image and a diff (red
    /// where it differs) are written to a temporary folder that the failure names.
    public static func expect(
        _ image: CGImage?,
        matches name: String,
        tolerance: Int = 2,
        allowedFraction: Double = 0,
        filePath: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let image else {
            Issue.record("Nothing was rendered for “\(name)”.", sourceLocation: sourceLocation)
            return
        }
        let url = referenceURL(name, filePath: filePath)
        if isRecording {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try write(image, to: url)
            } catch {
                Issue.record("Could not record \(url.path): \(error)", sourceLocation: sourceLocation)
            }
            return
        }
        guard let reference = load(url) else {
            Issue.record("No reference \(url.path); record it with ORIEL_RECORD_SNAPSHOTS=1.", sourceLocation: sourceLocation)
            return
        }
        let difference = compare(image, reference, tolerance: tolerance)
        guard !difference.sizesMatch || difference.fraction > allowedFraction else { return }
        let failures = FileManager.default.temporaryDirectory.appending(path: "OrielSnapshots", directoryHint: .isDirectory)
        let actual = failures.appending(path: name + osSuffix + ".png")
        let diff = failures.appending(path: name + osSuffix + "-diff.png")
        try? FileManager.default.createDirectory(at: failures, withIntermediateDirectories: true)
        try? write(image, to: actual)
        if let marked = diffImage(image, reference, tolerance: tolerance) {
            try? write(marked, to: diff)
        }
        let counts = "\(difference.differingPixels) of \(difference.pixelCount) pixels differ"
        let what = difference.sizesMatch
            ? "\(counts) (largest channel difference \(difference.largestChannelDifference))"
            : "the size is \(image.width)×\(image.height), the reference's \(reference.width)×\(reference.height)"
        Issue.record(
            "“\(name)” differs from its reference: \(what). Actual: \(actual.path); diff: \(diff.path)",
            sourceLocation: sourceLocation
        )
    }

    /// The reference, faded, with the pixels that differ in red.
    public static func diffImage(_ image: CGImage, _ reference: CGImage, tolerance: Int) -> CGImage? {
        guard image.width == reference.width, image.height == reference.height,
              let pixels = rgba(image), var marked = rgba(reference)
        else { return nil }
        for pixel in 0 ..< image.width * image.height {
            let base = pixel * 4
            let differs = (0 ..< 4).contains { abs(Int(pixels[base + $0]) - Int(marked[base + $0])) > tolerance }
            if differs {
                marked.replaceSubrange(base ..< base + 4, with: [255, 0, 0, 255])
            } else {
                for channel in 0 ..< 3 {
                    marked[base + channel] = UInt8(min(255, Int(marked[base + channel]) / 4 + 191))
                }
                marked[base + 3] = 255
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let provider = CGDataProvider(data: Data(marked) as CFData) else {
            return nil
        }
        return CGImage(
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    public static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    public static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// The image's pixels as sRGB RGBA, premultiplied, row by row from the top.
    public static func rgba(_ image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = bitmap(width: image.width, height: image.height, data: bytes.baseAddress) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? pixels : nil
    }

    private static func bitmap(width: Int, height: Int, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

public extension Trait where Self == ConditionTrait {
    /// Runs an image-diff test only where it can compare: when the references `names` were recorded on this macOS, or
    /// while recording them.
    static func snapshots(_ names: String..., filePath: String = #filePath) -> Self {
        .enabled(
            if: Snapshot.isRecording || names.allSatisfy {
                FileManager.default.fileExists(atPath: Snapshot.referenceURL($0, filePath: filePath).path)
            },
            "its references were recorded on another macOS"
        )
    }
}
