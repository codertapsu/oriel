import AVFoundation
import CoreImage

/// Draws each frame of a zoom composition (PLAN §17): the part of the source frame that the plan shows at the
/// frame's time, scaled to fill the render size, for the editor's preview, its exports and its GIFs alike.
///
/// Core Image does the work on the GPU. Colour management is off, so pixels that are only moved and scaled keep
/// their values; large reductions use Core Image's high-quality downsampling, which keeps small text legible.
/// AVFoundation calls the compositor on its own threads; it holds nothing that changes.
final nonisolated class ZoomCompositor: NSObject, AVVideoCompositing {
    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
    ]
    // The name is AVVideoCompositing's.
    // swiftlint:disable:next identifier_name
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
    ]
    private let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .cacheIntermediates: false,
        .highQualityDownsample: true,
    ])

    func renderContextChanged(_: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? ZoomInstruction,
              let source = request.sourceReadOnlyPixelBuffer(byTrackID: instruction.trackID)
        else {
            request.finish(with: VideoEditorError.noFrame)
            return
        }
        do {
            let output = try request.renderContext.makeMutablePixelBuffer()
            let size = request.renderContext.size
            let image = source.withUnsafeBuffer { buffer in
                Self.frame(
                    CIImage(cvPixelBuffer: buffer, options: [.colorSpace: NSNull()]),
                    instruction: instruction,
                    time: request.compositionTime.seconds,
                    renderSize: size
                )
            }
            output.withUnsafeBuffer { buffer in
                context.render(image, to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: nil)
            }
            request.finish(withComposedPixelBuffer: CVReadOnlyPixelBuffer(output))
        } catch {
            request.finish(with: error)
        }
    }

    /// One composited frame: the source turned upright, cropped to what the plan shows at `time` and scaled to
    /// fill `renderSize`. The crop never leaves the frame, and the edges are extended rather than sampled from
    /// outside it, so no dark border creeps in.
    static func frame(_ source: CIImage, instruction: ZoomInstruction, time: Double, renderSize: CGSize) -> CIImage {
        var image = instruction.orientation == .up ? source : source.oriented(instruction.orientation)
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let sourceSize = image.extent.size
        let crop = ZoomTransform.cropRect(for: instruction.plan.state(at: time), sourceSize: sourceSize)
        let transform = ZoomTransform.transform(crop: crop, sourceSize: sourceSize, outputSize: renderSize)
        return image.clampedToExtent().transformed(by: transform).cropped(to: CGRect(origin: .zero, size: renderSize))
    }
}
