import CoreGraphics
import CoreVideo
import Foundation
import OrielCore
import Vision

/// Finds objects Smart Move can lift (PLAN §17), with public Vision requests that run on this Mac:
/// `VNGenerateForegroundInstanceMaskRequest` for separate foreground objects (with masks) and
/// `VNGenerateObjectnessBasedSaliencyImageRequest` for salient regions (boxes). Both are older than macOS 26, so no
/// availability gate is needed; where one cannot run (it may not on some Macs), its part is simply empty.
nonisolated enum ObjectDetector {
    struct Detections: Sendable, Equatable {
        /// One coarse mask per foreground object, over the whole image.
        var objects: [MaskGrid] = []
        /// Salient regions in the image's pixels, top-left origin.
        var regions: [CGRect] = []
        /// Whether the foreground request could not run here.
        var objectsUnavailable = false
    }

    /// An object or region must cover at least this share of the image, and at most `maximumShare`: smaller ones
    /// are specks, larger ones are the whole screenshot.
    static let minimumShare = 0.0015
    static let maximumShare = 0.8
    static let maximumRegions = 8

    private static let log = Log.logger("editor")

    static func detect(in image: CGImage) -> Detections {
        var detections = Detections()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let foreground = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([foreground])
            if let observation = foreground.results?.first {
                detections.objects = masks(from: observation).filter { isUseful($0.share) }.map(\.grid)
            }
        } catch {
            detections.objectsUnavailable = true
            log.info("Foreground objects are not available: \(error.localizedDescription, privacy: .public)")
        }
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        do {
            try handler.perform([saliency])
            let size = CGSize(width: image.width, height: image.height)
            let boxes = (saliency.results?.first?.salientObjects ?? []).map { pixelRect(fromNormalized: $0.boundingBox, in: size) }
            detections.regions = Array(boxes.filter { isUseful($0.width * $0.height / (size.width * size.height)) }.prefix(maximumRegions))
        } catch {
            log.info("Salient regions are not available: \(error.localizedDescription, privacy: .public)")
        }
        return detections
    }

    /// One grid per instance from a label buffer (0 is the background, n the n-th instance), with the share of the
    /// image each covers.
    static func grids(labels: [UInt8], width: Int, height: Int, instances: [Int]) -> [(grid: MaskGrid, share: Double)] {
        guard width > 0, height > 0, labels.count >= width * height else { return [] }
        return instances.compactMap { instance in
            guard let label = UInt8(exactly: instance) else { return nil }
            var values = [Float](repeating: 0, count: width * height)
            var covered = 0
            for index in 0 ..< width * height where labels[index] == label {
                values[index] = 1
                covered += 1
            }
            guard covered > 0 else { return nil }
            return (MaskGrid(width: width, height: height, values: values), Double(covered) / Double(width * height))
        }
    }

    /// Vision's normalized, bottom-left-origin box in an image's pixels, top-left origin.
    static func pixelRect(fromNormalized box: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height, width: box.width * size.width, height: box.height * size.height)
    }

    private static func isUseful(_ share: Double) -> Bool {
        share >= minimumShare && share <= maximumShare
    }

    private static func masks(from observation: VNInstanceMaskObservation) -> [(grid: MaskGrid, share: Double)] {
        let instances = Array(observation.allInstances)
        let buffer = observation.instanceMask
        if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8, let labels = labels(of: buffer) {
            return grids(labels: labels.values, width: labels.width, height: labels.height, instances: instances)
        }
        // Another label format: ask for each instance's own soft mask instead.
        return instances.compactMap { instance in
            guard let mask = try? observation.generateMask(forInstances: IndexSet(integer: instance)), let grid = floatGrid(of: mask) else {
                return nil
            }
            let share = Double(grid.values.count { $0 >= 0.5 }) / Double(max(grid.values.count, 1))
            return (grid, share)
        }
    }

    private static func labels(of buffer: CVPixelBuffer) -> (values: [UInt8], width: Int, height: Int)? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var values = [UInt8](repeating: 0, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                values[y * width + x] = base.load(fromByteOffset: y * bytesPerRow + x, as: UInt8.self)
            }
        }
        return (values, width, height)
    }

    private static func floatGrid(of buffer: CVPixelBuffer) -> MaskGrid? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent32Float else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Float](repeating: 0, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                values[y * width + x] = base.load(fromByteOffset: y * bytesPerRow + x * MemoryLayout<Float>.size, as: Float.self)
            }
        }
        return MaskGrid(width: width, height: height, values: values)
    }
}
