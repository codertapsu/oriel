import AVFoundation
import CoreGraphics

/// The timeline's filmstrip images (PLAN §17), made by `AVAssetImageGenerator` in the background and kept for
/// reuse while the timeline scrolls and zooms.
///
/// The timeline asks for the times it shows; only the missing ones are made, and a new request replaces one still
/// running. At most `capacity` images are kept, the oldest going first.
final class ThumbnailCache {
    /// About 20 MB of thumbnails for a 16:9 movie.
    static let capacity = 240

    /// Called on the main thread when new images are ready.
    var onUpdate: (() -> Void)?

    /// The images' size in pixels.
    let pixelSize: CGSize
    private let generator: AVAssetImageGenerator
    private var images: [Int: CGImage] = [:]
    private var order: [Int] = []
    /// Times asked for already, so a frame the decoder cannot make is not asked for on every redraw.
    private var requested: Set<Int> = []
    /// Times the running request has not delivered yet.
    private var inFlight: Set<Int> = []
    private var request: Task<Void, Never>?

    /// Thumbnails of `info`'s movie, `height` pixels high.
    init(info: MovieInfo, height: CGFloat) {
        let aspect = info.size.height > 0 ? info.size.width / info.size.height : 16.0 / 9.0
        pixelSize = CGSize(width: (height * aspect).rounded(), height: height)
        generator = AVAssetImageGenerator(asset: AVURLAsset(url: info.url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = pixelSize
    }

    /// Stops making images.
    func cancel() {
        request?.cancel()
        request = nil
    }

    /// The image made for the time nearest `time`, within `tolerance` seconds, if there is one.
    func image(near time: Double, tolerance: Double) -> CGImage? {
        let key = Self.key(time)
        if let exact = images[key] {
            return exact
        }
        let reach = Int((tolerance * 100).rounded(.up))
        let nearest = order.min { abs($0 - key) < abs($1 - key) }
        guard let nearest, abs(nearest - key) <= reach else { return nil }
        return images[nearest]
    }

    /// Makes images for `times` that have none yet; `tolerance` is how far from a time its frame may be, which
    /// lets the decoder use nearby key frames. Times already on their way, made, or not makeable are skipped, so
    /// redrawing while images arrive asks for nothing new.
    func request(_ times: [Double], tolerance: Double) {
        let wanted = Set(times.map(Self.key)).filter { images[$0] == nil }
        guard !wanted.subtracting(requested).isEmpty else { return }
        request?.cancel()
        // What the cancelled request had not reached yet may be asked for again.
        requested.subtract(inFlight)
        if requested.count > 4 * Self.capacity {
            requested = Set(order)
        }
        let keys = wanted.subtracting(requested).sorted()
        requested.formUnion(keys)
        inFlight = Set(keys)
        let tolerance = CMTime(seconds: max(tolerance, 0), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let times = keys.map { CMTime(value: CMTimeValue($0), timescale: 100) }
        let generator = generator
        request = Task { [weak self] in
            var failed: [CMTime] = []
            await self?.make(times, with: generator, failed: &failed)
            // A tolerance lets the decoder skip work, but it fails some times of a sparse screen recording that an
            // exact request reads (macOS 27.0.1), so those are asked for once more, exactly.
            guard !failed.isEmpty, !Task.isCancelled else { return }
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            var stillFailed: [CMTime] = []
            await self?.make(failed, with: generator, failed: &stillFailed)
        }
    }

    private func make(_ times: [CMTime], with generator: AVAssetImageGenerator, failed: inout [CMTime]) async {
        var added = 0
        for await result in generator.images(for: times) {
            guard !Task.isCancelled else { return }
            let key = Self.key(result.requestedTime.seconds)
            guard let image = try? result.image else {
                failed.append(result.requestedTime)
                continue
            }
            inFlight.remove(key)
            store(image, key: key)
            added += 1
            // Delivered in small batches, so the strip fills in without redrawing for every image.
            if added % 4 == 0 {
                onUpdate?()
            }
        }
        for time in failed {
            inFlight.remove(Self.key(time.seconds))
        }
        onUpdate?()
    }

    /// The newest image made for a time at or before `time`, within `reach` seconds: a screen recording shows
    /// the same picture until something changes, so it stands in for a frame that could not be read.
    func image(before time: Double, reach: Double) -> CGImage? {
        let key = Self.key(time)
        let lowest = key - Int((reach * 100).rounded(.up))
        let earlier = order.filter { $0 <= key && $0 >= lowest }.max()
        return earlier.flatMap { images[$0] }
    }

    private func store(_ image: CGImage, key: Int) {
        if images[key] == nil {
            order.append(key)
        }
        images[key] = image
        while order.count > Self.capacity {
            let evicted = order.removeFirst()
            images[evicted] = nil
            requested.remove(evicted)
        }
    }

    /// Times are kept to the hundredth of a second.
    private static func key(_ time: Double) -> Int {
        Int((time * 100).rounded())
    }
}
