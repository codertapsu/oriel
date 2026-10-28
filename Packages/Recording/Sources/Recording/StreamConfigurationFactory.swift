import AVFoundation
import CoreMedia
import ScreenCaptureKit

/// Turns recording options into ScreenCaptureKit configuration objects (PLAN §7.4). Building them starts nothing,
/// so they are unit-tested.
enum StreamConfigurationFactory {
    static let sampleRate = 48000
    static let channelCount = 2
    /// PLAN §9: frames buffered by the stream before it drops one.
    static let queueDepth = 5
    static let streamName = "Oriel Recording"

    /// The stream configuration for `options` (whose `microphone` flag must already reflect the permission).
    static func stream(options: RecordingOptions, geometry: CaptureGeometry) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let size = geometry.outputSize(resolution: options.preset.resolution, codec: options.codec)
        configuration.width = size.width
        configuration.height = size.height
        configuration.sourceRect = geometry.sourceRect
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.frameRate))
        configuration.showsCursor = options.showsCursor
        configuration.capturesAudio = options.systemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = sampleRate
        configuration.channelCount = channelCount
        configuration.captureMicrophone = options.microphone
        configuration.microphoneCaptureDeviceID = options.microphone ? options.microphoneDeviceID : nil
        configuration.queueDepth = queueDepth
        configuration.captureResolution = options.preset.resolution == .native ? .best : .automatic
        configuration.streamName = streamName
        return configuration
    }

    /// The configuration of one segment file: MP4 in the chosen codec. On macOS 27 system audio and the microphone
    /// stay two tracks; macOS 26 always mixes them into one (S8).
    static func output(url: URL, codec: VideoCodec) -> SCRecordingOutputConfiguration {
        let configuration = SCRecordingOutputConfiguration()
        configuration.outputURL = url
        configuration.outputFileType = .mp4
        configuration.videoCodecType = codec.avCodecType
        if #available(macOS 27, *) {
            configuration.mixesAudioWithMicrophone = false
        }
        return configuration
    }

    /// `codec`, or H.264 when the recording output cannot write it (HEVC on Macs without an HEVC encoder).
    static func supportedCodec(_ codec: VideoCodec) -> VideoCodec {
        let available = SCRecordingOutputConfiguration().availableVideoCodecTypes
        return available.contains(codec.avCodecType) ? codec : .h264
    }
}
