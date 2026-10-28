import AVFoundation
import CoreMedia
@testable import Recording
import ScreenCaptureKit
import Testing

/// Building configurations starts no capture and needs no permission.
@MainActor
struct StreamConfigurationTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func configuration(_ options: RecordingOptions, area: CGRect? = nil) throws -> SCStreamConfiguration {
        let geometry = try #require(CaptureGeometry(area: area, displayFrame: laptop, scale: 2))
        return StreamConfigurationFactory.stream(options: options, geometry: geometry)
    }

    @Test func standardIs1080pAt30FramesPerSecond() throws {
        let options = RecordingOptions(preset: .standard)
        let configuration = try configuration(options)
        #expect(configuration.width == 1662)
        #expect(configuration.height == 1080)
        #expect(configuration.minimumFrameInterval == CMTime(value: 1, timescale: 30))
        #expect(options.codec == .h264)
        #expect(configuration.sourceRect == laptop)
        #expect(configuration.captureResolution == .automatic)
    }

    @Test func highIsNativeAt60FramesPerSecondInHEVC() throws {
        let options = RecordingOptions(preset: .high)
        let configuration = try configuration(options)
        #expect(configuration.width == 3024)
        #expect(configuration.height == 1964)
        #expect(configuration.minimumFrameInterval == CMTime(value: 1, timescale: 60))
        #expect(options.codec == .hevc)
        #expect(configuration.captureResolution == .best)
    }

    @Test func smallIs720pAt24FramesPerSecond() throws {
        let options = RecordingOptions(preset: .small)
        let configuration = try configuration(options)
        #expect(configuration.width == 1108)
        #expect(configuration.height == 720)
        #expect(configuration.minimumFrameInterval == CMTime(value: 1, timescale: 24))
        #expect(options.codec == .h264)
    }

    @Test func settingsOverrideThePresetsRateAndCodec() throws {
        let options = RecordingOptions(preset: .standard, frameRate: 60, codec: .hevc)
        let configuration = try configuration(options)
        #expect(configuration.minimumFrameInterval == CMTime(value: 1, timescale: 60))
        #expect(options.codec == .hevc)
        #expect(RecordingOptions(preset: .high, frameRate: 0).frameRate == 60)
        #expect(RecordingOptions(preset: .small, frameRate: 500).frameRate == 24)
    }

    @Test func audioAndCursorFollowTheOptions() throws {
        let quiet = try configuration(RecordingOptions(showsCursor: false, systemAudio: false, microphone: false))
        #expect(!quiet.showsCursor)
        #expect(!quiet.capturesAudio)
        #expect(!quiet.captureMicrophone)
        #expect(quiet.microphoneCaptureDeviceID == nil)

        let loud = try configuration(RecordingOptions(microphone: true, microphoneDeviceID: "BuiltInMicrophoneDevice"))
        #expect(loud.showsCursor)
        #expect(loud.capturesAudio)
        #expect(loud.excludesCurrentProcessAudio)
        #expect(loud.sampleRate == 48000)
        #expect(loud.channelCount == 2)
        #expect(loud.captureMicrophone)
        #expect(loud.microphoneCaptureDeviceID == "BuiltInMicrophoneDevice")

        let systemDefault = try configuration(RecordingOptions(microphone: true, microphoneDeviceID: ""))
        #expect(systemDefault.captureMicrophone)
        #expect(systemDefault.microphoneCaptureDeviceID == nil)
    }

    @Test func buffersFiveFrames() throws {
        let configuration = try configuration(RecordingOptions())
        #expect(configuration.queueDepth == 5)
        #expect(configuration.streamName == StreamConfigurationFactory.streamName)
    }

    @Test func aRegionUsesTheDisplaysOwnPoints() throws {
        let configuration = try configuration(RecordingOptions(preset: .high), area: CGRect(x: 200, y: 100, width: 640, height: 360))
        #expect(configuration.sourceRect == CGRect(x: 200, y: 100, width: 640, height: 360))
        #expect(configuration.width == 1280)
        #expect(configuration.height == 720)
    }

    @Test(arguments: VideoCodec.allCases)
    func segmentsAreMP4InTheChosenCodec(codec: VideoCodec) {
        let url = URL(filePath: "/tmp/segment-000.mp4")
        let configuration = StreamConfigurationFactory.output(url: url, codec: codec)
        #expect(configuration.outputURL == url)
        #expect(configuration.outputFileType == .mp4)
        #expect(configuration.videoCodecType == codec.avCodecType)
    }

    @Test func keepsSystemAudioAndTheMicrophoneApartOnMacOS27() {
        guard #available(macOS 27, *) else { return }
        let configuration = StreamConfigurationFactory.output(url: URL(filePath: "/tmp/a.mp4"), codec: .h264)
        #expect(!configuration.mixesAudioWithMicrophone)
    }

    @Test func h264IsAlwaysSupported() {
        #expect(StreamConfigurationFactory.supportedCodec(.h264) == .h264)
        #expect(VideoCodec.allCases.contains(StreamConfigurationFactory.supportedCodec(.hevc)))
    }
}
