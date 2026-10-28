import AVFoundation
import CoreVideo
import Foundation

/// Writes short H.264 movies from synthetic frames with `AVAssetWriter`, so the movie pipelines are tested without
/// recording the screen. Every frame has its own colour, so the encoder cannot merge frames.
enum TestMovie {
    /// A movie whose frames start at `frameTimes` (seconds) and that ends at `duration`.
    static func write(
        to url: URL,
        width: Int = 320,
        height: Int = 180,
        frameTimes: [Double],
        duration: Double
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height)
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        for (index, time) in frameTimes.enumerated() {
            let frame = try makeFrame(attributes, index: index)
            try await receiver.append(frame, with: CMTime(seconds: time, preferredTimescale: 600))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }

    /// A constant-frame-rate movie of `duration` seconds.
    static func write(
        to url: URL,
        width: Int = 320,
        height: Int = 180,
        duration: Double,
        frameRate: Int = 30
    ) async throws {
        let count = Int((duration * Double(frameRate)).rounded())
        let times = (0 ..< count).map { Double($0) / Double(frameRate) }
        try await write(to: url, width: width, height: height, frameTimes: times, duration: duration)
    }

    private static func makeFrame(_ attributes: CVPixelBufferCreationAttributes, index: Int) throws -> CVReadOnlyPixelBuffer {
        var buffer = try CVMutablePixelBuffer(attributes)
        let width = attributes.size.width
        // BGRA, little-endian: 0xAARRGGBB.
        let colour = 0xFF00_0000 | UInt32((index * 37) % 256) << 16 | UInt32((index * 91) % 256) << 8 | UInt32((index * 53) % 256)
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            for plane in planes {
                for row in 0 ..< plane.properties.size.height {
                    let start = row * plane.properties.bytesPerRow
                    let pixels = UnsafeMutableRawBufferPointer(rebasing: plane.bytes[start ..< start + width * 4])
                    pixels.initializeMemory(as: UInt32.self, repeating: colour)
                }
            }
        }
        return CVReadOnlyPixelBuffer(buffer)
    }
}
