import CoreGraphics

/// Runs `ScrollStitcher` off the main thread for a scrolling capture session. Owning the stitcher here keeps its
/// growing buffer uniquely referenced, so adding rows never copies what was stitched so far.
actor StitchingWorker {
    private let direction: ScrollDirection
    private let configuration: ScrollStitcher.Configuration
    private let colorSpace: CGColorSpace
    private var stitcher: ScrollStitcher?

    init(direction: ScrollDirection, configuration: ScrollStitcher.Configuration, colorSpace: CGColorSpace) {
        self.direction = direction
        self.configuration = configuration
        self.colorSpace = colorSpace
    }

    /// Starts over with `image` as the first frame. False when the image could not be read.
    func start(with image: CGImage) -> Bool {
        guard let frame = PixelFrame(image: image, colorSpace: colorSpace) else { return false }
        stitcher = ScrollStitcher(first: frame, direction: direction, configuration: configuration)
        return true
    }

    func add(_ image: CGImage, expectedOffset: Int?) -> ScrollStitcher.Step {
        guard let frame = PixelFrame(image: image, colorSpace: colorSpace) else { return .lowConfidence }
        return stitcher?.add(frame, expectedOffset: expectedOffset) ?? .lowConfidence
    }

    var length: Int {
        stitcher?.length ?? 0
    }

    var frameCount: Int {
        stitcher?.frameCount ?? 0
    }

    /// Whether two captures of the region show the same thing: the content has settled, or did not move.
    func matches(_ first: CGImage, _ second: CGImage) -> Bool {
        guard let one = PixelFrame(image: first, colorSpace: colorSpace),
              let other = PixelFrame(image: second, colorSpace: colorSpace)
        else {
            return false
        }
        let mask = configuration.maskWidth
        return GrayFrame(one, maskWidth: mask).matches(GrayFrame(other, maskWidth: mask), tolerance: configuration.sameTolerance)
    }

    /// The stitched image, footer included.
    func finish() -> CGImage? {
        stitcher?.finish().makeImage(colorSpace: colorSpace)
    }
}
