import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Renders a finished movie as a looping GIF: `AVAssetImageGenerator` samples it at 10–15 fps and
/// `CGImageDestination` writes `UTType.gif`, at most `maxWidth` pixels wide (PLAN §7.4). Runs off the main actor.
///
/// The video editor's GIF export samples its trimmed, zoomed composition the same way (PLAN §17).
nonisolated enum GIFExporter {
    /// Writes `movie` as a GIF to `output` and returns the number of frames written. A failed or cancelled export
    /// leaves no file behind.
    @concurrent
    @discardableResult
    static func export(_ movie: URL, to output: URL, options: GIFExportOptions) async throws -> Int {
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw RecordingError.exportFailed("The movie has no video.")
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let size = naturalSize.applying(transform)
        let plan = GIFFramePlan(
            duration: duration.seconds,
            frameRate: options.frameRate,
            sourceWidth: Int(abs(size.width).rounded()),
            sourceHeight: Int(abs(size.height).rounded()),
            maxWidth: options.maxWidth
        )
        return try await export(asset, videoComposition: nil, plan: plan, to: output, options: options)
    }

    /// Writes the frames of `asset` at the times of `plan` as a GIF, drawn through `videoComposition` when there
    /// is one (whose render size should be the plan's), reporting progress from 0 to 1.
    @discardableResult
    static func export(
        _ asset: AVAsset,
        videoComposition: AVVideoComposition?,
        plan: GIFFramePlan,
        to output: URL,
        options: GIFExportOptions,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Int {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.videoComposition = videoComposition
        generator.maximumSize = CGSize(width: plan.width, height: plan.height)
        // Screen recordings hold a frame until the screen changes, so the nearest frame within half a GIF frame
        // is the right one, and decoding to the exact time would only cost time.
        let tolerance = CMTime(seconds: 0.5 / Double(options.frameRate), preferredTimescale: 6000)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL, UTType.gif.identifier as CFString, plan.times.count, nil
        ) else {
            throw RecordingError.exportFailed("A GIF cannot be written to this folder.")
        }
        // A palette per frame: ImageIO then encodes each frame as it is added. With one global palette it keeps every
        // frame until it finalizes, about 4 MB per 800 × 450 frame (1.2 GB for 30 s at 10 fps, macOS 27.0.1).
        let fileProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0,
                kCGImagePropertyGIFHasGlobalColorMap: false,
            ],
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        do {
            let written = try await addFrames(
                from: generator,
                plan: plan,
                frameRate: options.frameRate,
                to: destination,
                progress: progress
            )
            guard written > 0, CGImageDestinationFinalize(destination) else {
                throw RecordingError.exportFailed("No frame of the movie could be read.")
            }
            return written
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    /// Adds one image per planned time. A time the decoder cannot produce (usually the very end) repeats the
    /// previous frame, or, before the first frame, lends its time to the next one, so the GIF keeps its length.
    private static func addFrames(
        from generator: AVAssetImageGenerator,
        plan: GIFFramePlan,
        frameRate: Int,
        to destination: CGImageDestination,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> Int {
        let times = plan.times.map { CMTime(seconds: $0, preferredTimescale: 6000) }
        var written = 0
        var handled = 0
        var previous: CGImage?
        var carried = 0.0
        for await result in generator.images(for: times) {
            try Task.checkCancellation()
            handled += 1
            progress?(Double(handled) / Double(max(times.count, 1)) * 0.99)
            let index = min(max(Int((result.requestedTime.seconds * Double(frameRate)).rounded()), 0), plan.delays.count - 1)
            let delay = plan.delays[index] + carried
            guard let image = (try? result.image).map({ fitted($0, plan: plan) }) ?? previous else {
                carried = delay
                continue
            }
            carried = 0
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay,
                ],
            ]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            previous = image
            written += 1
        }
        return written
    }

    /// The image at exactly the planned size. The generator fits images within `maximumSize`, which can be a pixel
    /// short of it after rounding.
    private static func fitted(_ image: CGImage, plan: GIFFramePlan) -> CGImage {
        guard image.width != plan.width || image.height != plan.height,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: plan.width,
                  height: plan.height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: plan.width, height: plan.height))
        return context.makeImage() ?? image
    }
}
