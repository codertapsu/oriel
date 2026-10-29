import AVFoundation
import CoreAudio
import CoreVideo
import Foundation

/// Synthetic movies for the video editor's tests, written with `AVAssetWriter`: frames painted by a closure, at
/// chosen times (a still screen has few), and optional sound tracks of a quiet tone.
enum PatternMovie {
    /// An opaque colour as 0xRRGGBB.
    typealias Painter = @Sendable (_ frame: Int, _ x: Int, _ y: Int, _ width: Int, _ height: Int) -> UInt32

    /// Red, green, blue and white quarters (top-left, top-right, bottom-left, bottom-right).
    static let quadrants: Painter = { _, x, y, width, height in
        switch (y < height / 2, x < width / 2) {
        case (true, true): 0xFF0000
        case (true, false): 0x00FF00
        case (false, true): 0x0000FF
        case (false, false): 0xFFFFFF
        }
    }

    /// Writes an H.264 movie of `duration` seconds whose frames start at `frameTimes`, with `audioTracks` sound
    /// tracks of `duration` seconds.
    static func write(
        to url: URL,
        width: Int = 320,
        height: Int = 180,
        frameTimes: [Double],
        duration: Double,
        audioTracks: Int = 0,
        painter: @escaping Painter = quadrants
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height)
        )
        let video = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        var sounds: [AVAssetWriterInput.SampleBufferReceiver] = []
        for _ in 0 ..< audioTracks {
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
            ])
            audio.expectsMediaDataInRealTime = false
            sounds.append(writer.inputReceiver(for: audio))
        }
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        try await withThrowingTaskGroup(of: Void.self) { group in
            let frames = UnsafeTransfer(video)
            group.addTask {
                for (index, time) in frameTimes.enumerated() {
                    let frame = try makeFrame(attributes, index: index, painter: painter)
                    try await frames.value.append(frame, with: CMTime(seconds: time, preferredTimescale: 600))
                }
                frames.value.finish()
            }
            for sound in sounds {
                let receiver = UnsafeTransfer(sound)
                group.addTask {
                    try await writeTone(duration: duration, into: receiver.value)
                }
            }
            try await group.waitForAll()
        }
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }

    /// The sample at `(x, y)` of `image` as 0xRRGGBB.
    static func colour(in image: CGImage, x: Int, y: Int) -> UInt32 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        }
        return UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
    }

    /// Whether two colours are within `tolerance` per channel, as video compression allows.
    static func isClose(_ lhs: UInt32, _ rhs: UInt32, tolerance: Int = 40) -> Bool {
        [16, 8, 0].allSatisfy { shift in
            abs(Int((lhs >> UInt32(shift)) & 0xFF) - Int((rhs >> UInt32(shift)) & 0xFF)) <= tolerance
        }
    }

    private static func makeFrame(
        _ attributes: CVPixelBufferCreationAttributes,
        index: Int,
        painter: Painter
    ) throws -> CVReadOnlyPixelBuffer {
        var buffer = try CVMutablePixelBuffer(attributes)
        let width = attributes.size.width
        let height = attributes.size.height
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            for plane in planes {
                for row in 0 ..< height {
                    let start = row * plane.properties.bytesPerRow
                    let pixels = UnsafeMutableRawBufferPointer(rebasing: plane.bytes[start ..< start + width * 4])
                    for column in 0 ..< width {
                        // BGRA in memory, little-endian: 0xAARRGGBB.
                        pixels.storeBytes(
                            of: 0xFF00_0000 | painter(index, column, row, width, height),
                            toByteOffset: column * 4,
                            as: UInt32.self
                        )
                    }
                }
            }
        }
        return CVReadOnlyPixelBuffer(buffer)
    }

    /// A quiet 440 Hz stereo tone in one-second buffers.
    private static func writeTone(duration: Double, into receiver: AVAssetWriterInput.SampleBufferReceiver) async throws {
        let rate = 48000
        let description = AudioStreamBasicDescription(
            mSampleRate: Double(rate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let format = try CMAudioFormatDescription(audioStreamBasicDescription: description)
        let total = Int(duration * Double(rate))
        var written = 0
        while written < total {
            let count = min(rate, total - written)
            var samples = [Float](repeating: 0, count: count * 2)
            for frame in 0 ..< count {
                let value = Float(sin(Double(written + frame) * 2 * .pi * 440 / Double(rate)) * 0.1)
                samples[frame * 2] = value
                samples[frame * 2 + 1] = value
            }
            let data = samples.withUnsafeBufferPointer { Data(buffer: $0) }
            let buffer = CMReadySampleBuffer(
                audioDataBuffer: CMReadOnlyDataBlockBuffer(data),
                formatDescription: format,
                sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(written), timescale: CMTimeScale(rate))
            )
            try await receiver.append(CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(buffer))
            written += count
        }
        receiver.finish()
    }
}

/// Hands a value that is not `Sendable` to one child task, which is then its only user.
struct UnsafeTransfer<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
