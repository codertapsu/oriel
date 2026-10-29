import CoreImage
import CoreVideo
import Vision

/// Oriel's own camera background effect (PLAN §17): Vision finds the person in a camera frame
/// (`VNGeneratePersonSegmentationRequest`, balanced quality) and Core Image blurs everything else, or replaces it
/// with a color, then fits the picture to the bubble, mirrored like a mirror.
///
/// It lives on the camera's queue and is used from there only. `SegmentationGovernor` decides how often to
/// segment and when to stop; after it stops, `render` returns nil and the bubble shows the camera as it is.
final nonisolated class CameraBackgroundRenderer {
    private let background: CameraBackground
    /// The bubble's size in pixels.
    private let outputSize: CGSize
    private let request = VNGeneratePersonSegmentationRequest()
    private let handler = VNSequenceRequestHandler()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var mask: CIImage?
    private var governor = SegmentationGovernor()

    init(background: CameraBackground, outputSize: CGSize) {
        self.background = background
        self.outputSize = CGSize(width: max(outputSize.width.rounded(), 2), height: max(outputSize.height.rounded(), 2))
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    /// Why the effect turned off, once it has.
    var stopReason: String? {
        governor.stopReason
    }

    /// The bubble's picture for the camera frame shown at `time` (seconds), or nil once the effect is off.
    func render(_ frame: CVPixelBuffer, time: Double) -> CGImage? {
        guard governor.isRunning else { return nil }
        if governor.shouldSegment(at: time) {
            let clock = ContinuousClock()
            let start = clock.now
            if let mask = segment(frame) {
                self.mask = mask
            }
            governor.record(cost: (clock.now - start) / .seconds(1))
            guard governor.isRunning else { return nil }
        }
        // Fitted to the bubble first, so blurring and blending cost what the bubble's size does, whatever the
        // camera's resolution.
        let source = CIImage(cvPixelBuffer: frame)
        let bounds = CGRect(origin: .zero, size: outputSize)
        let fit = Self.fillTransform(from: source.extent, to: outputSize, mirrored: true)
        let picture = source.transformed(by: fit).cropped(to: bounds)
        let fittedMask = mask.map { mask in
            mask.transformed(by: CGAffineTransform(
                scaleX: source.extent.width / mask.extent.width,
                y: source.extent.height / mask.extent.height
            ))
            .transformed(by: CGAffineTransform(translationX: source.extent.minX, y: source.extent.minY))
            .transformed(by: fit)
            .cropped(to: bounds)
        }
        return context.createCGImage(Self.composite(picture, mask: fittedMask, background: background), from: bounds)
    }

    /// Passes the Mac's heat and power state to the governor.
    func observe(thermalState: ProcessInfo.ThermalState, lowPowerMode: Bool) {
        governor.observe(thermalState: thermalState, lowPowerMode: lowPowerMode)
    }

    /// The person's mask for `frame`: white where the person is.
    private func segment(_ frame: CVPixelBuffer) -> CIImage? {
        do {
            try handler.perform([request], on: frame, orientation: .up)
        } catch {
            return nil
        }
        return request.results?.first.map { CIImage(cvPixelBuffer: $0.pixelBuffer) }
    }

    /// `image` with everything but the person blurred or replaced. Before the first mask everything counts as
    /// background, so the room is never shown unblurred.
    static func composite(_ image: CIImage, mask: CIImage?, background: CameraBackground) -> CIImage {
        let extent = image.extent
        let backdrop: CIImage
        switch background {
        case .unchanged:
            return image
        case .blurred:
            let sigma = max(extent.height / 36, 4)
            backdrop = image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        case let .replaced(red, green, blue):
            backdrop = CIImage(color: CIColor(cgColor: CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))).cropped(to: extent)
        }
        guard let mask, mask.extent.width > 0, mask.extent.height > 0 else { return backdrop }
        let scaled = mask
            .transformed(by: CGAffineTransform(scaleX: extent.width / mask.extent.width, y: extent.height / mask.extent.height))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
        return image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: backdrop,
            kCIInputMaskImageKey: scaled,
        ])
    }

    /// The middle of `image` scaled to fill `size`, mirrored left to right when `mirrored`.
    static func fill(_ image: CIImage, to size: CGSize, mirrored: Bool) -> CIImage {
        image.transformed(by: fillTransform(from: image.extent, to: size, mirrored: mirrored))
            .cropped(to: CGRect(origin: .zero, size: size))
    }

    /// Maps `extent` so that its middle fills `size` at the origin, mirrored left to right when `mirrored`.
    static func fillTransform(from extent: CGRect, to size: CGSize, mirrored: Bool) -> CGAffineTransform {
        guard extent.width > 0, extent.height > 0 else { return .identity }
        let scale = max(size.width / extent.width, size.height / extent.height)
        return CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
            .concatenating(CGAffineTransform(scaleX: mirrored ? -scale : scale, y: scale))
            .concatenating(CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
    }
}
