import AVFoundation
import Foundation
import OrielCore
import os

/// Writes the video editor's result (PLAN §17): the kept part of the movie, zoomed where the plan says, at the
/// chosen size, in H.264 or HEVC, with its sound mixed to stereo AAC and its chapters as a QuickTime chapter track,
/// as MPEG-4 or QuickTime; or the same frames as a GIF.
///
/// Uses `AVAssetReader` and `AVAssetWriter` with their async receivers (macOS 26), never the deprecated callback
/// export (S8): an export session cannot write a chapter track. Video, sound and chapters are written by three
/// child tasks, so the writer can interleave them. Everything goes to a hidden file next to the destination
/// first, which replaces the destination only when complete; a failed or cancelled export leaves nothing behind.
nonisolated enum EditedMovieExporter {
    /// What to export.
    struct Request: Sendable {
        let source: URL
        let destination: URL
        let edit: VideoEdit
        let options: VideoExportOptions
    }

    private static let log = Log.logger("video-editor")

    /// Exports, reporting progress from 0 to 1 (at most about a hundred times). Cancelling the task cancels it.
    @concurrent
    static func export(_ request: Request, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        guard request.source.standardizedFileURL != request.destination.standardizedFileURL else {
            throw VideoEditorError.replacesSource
        }
        let info = try await MovieInfo.load(request.source)
        let range = request.edit.range(duration: info.duration)
        guard range.upperBound - range.lowerBound >= VideoEdit.minimumLength else { throw VideoEditorError.tooShort }
        let asset = AVURLAsset(url: request.source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let trimmed = try await TrimmedMovie.make(asset, range: range)
        let temporary = temporaryURL(for: request.destination)
        do {
            if request.options.format == .gif {
                try await writeGIF(
                    trimmed,
                    info: info,
                    plan: request.edit.zoomPlan.trimmed(to: range),
                    options: request.options,
                    to: temporary,
                    progress: progress
                )
            } else {
                let chapters = ChapterList.build(request.edit.chapters, range: range)
                let movie = Movie(trimmed: trimmed, info: info, plan: request.edit.zoomPlan.trimmed(to: range), chapters: chapters)
                try await write(movie, options: request.options, to: temporary, progress: progress)
            }
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: request.destination.path) {
                _ = try FileManager.default.replaceItemAt(request.destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: request.destination)
            }
            removeLeftovers(of: temporary)
            progress(1)
        } catch {
            removeLeftovers(of: temporary)
            if !(error is CancellationError) {
                log.error("export failed: \(error.localizedDescription, privacy: .public)")
            }
            throw mapped(error)
        }
    }

    /// A hidden file next to `destination`, so the final move is a rename on the same volume.
    static func temporaryURL(for destination: URL) -> URL {
        let name = ".\(destination.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).\(destination.pathExtension)"
        return destination.deletingLastPathComponent().appending(path: name, directoryHint: .notDirectory)
    }

    /// Deletes the temporary file and anything named after it: a writer that optimizes for network use keeps a
    /// `<file>.sb-…` scratch file of its own, which a cancelled export leaves behind and a finished one may still
    /// have for a moment (macOS 27.0.1).
    static func removeLeftovers(of temporary: URL) {
        let manager = FileManager.default
        let folder = temporary.deletingLastPathComponent()
        let name = temporary.lastPathComponent
        let names = (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        for leftover in names where leftover.hasPrefix(name) {
            try? manager.removeItem(at: folder.appending(path: leftover, directoryHint: .notDirectory))
        }
    }

    /// The frame rate of a zoomed export: the movie's own, between 24 and 60 frames per second.
    static func zoomFrameRate(for info: MovieInfo) -> Double {
        min(max(info.frameRate, 24), 60)
    }

    // MARK: Movies

    /// Everything one movie export reads.
    private struct Movie {
        let trimmed: TrimmedMovie
        let info: MovieInfo
        let plan: ZoomPlan
        let chapters: [ExportedChapter]
    }

    private static func write(
        _ movie: Movie,
        options: VideoExportOptions,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let fileType = options.format.fileType else { return }
        let size = options.size.pixelSize(for: movie.info.size, codec: options.codec)
        let frameRate = movie.plan.isEmpty ? movie.info.frameRate : zoomFrameRate(for: movie.info)
        let length = movie.trimmed.duration

        let reader = try AVAssetReader(asset: movie.trimmed.composition)
        let videoProvider = reader.outputProvider(for: videoOutput(for: movie, size: size, frameRate: frameRate))
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        writer.shouldOptimizeForNetworkUse = true
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings(size: size, frameRate: frameRate, codec: options.codec)
        )
        videoInput.expectsMediaDataInRealTime = false
        let videoReceiver = writer.inputReceiver(for: videoInput)

        var audioProvider: AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>?
        var audioReceiver: AVAssetWriterInput.SampleBufferReceiver?
        if !movie.trimmed.audioTracks.isEmpty {
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: movie.trimmed.audioTracks, audioSettings: pcmSettings)
            audioOutput.alwaysCopiesSampleData = false
            audioProvider = reader.outputProvider(for: audioOutput)
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: aacSettings)
            audioInput.expectsMediaDataInRealTime = false
            audioReceiver = writer.inputReceiver(for: audioInput)
        }
        let chapterReceiver = movie.chapters.isEmpty ? nil : try chapterInput(for: writer, listedBy: videoInput)

        let chapters = movie.chapters
        try reader.start()
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        do {
            async let video: Void = pumpVideo(videoProvider, into: videoReceiver, length: length, progress: progress)
            async let audio: Void = pumpAudio(audioProvider, into: audioReceiver)
            async let text: Void = writeChapters(chapters, into: chapterReceiver)
            _ = try await (video, audio, text)
            if reader.status == .failed {
                throw reader.error ?? VideoEditorError.exportFailed("The movie could not be read.")
            }
            writer.endSession(atSourceTime: CMTime(seconds: length, preferredTimescale: 60000))
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw writer.error ?? VideoEditorError.exportFailed("The file could not be written.")
            }
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
    }

    /// The kept part's frames, through the zoom composition, at the export's size.
    private static func videoOutput(for movie: Movie, size: CGSize, frameRate: Double) -> AVAssetReaderVideoCompositionOutput {
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [movie.trimmed.videoTrack],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = ZoomComposition.make(
            ZoomComposition.Source(trackID: movie.trimmed.videoTrack.trackID, size: movie.info.size, orientation: movie.info.orientation),
            duration: movie.trimmed.duration,
            plan: movie.plan,
            renderSize: size,
            frameRate: frameRate,
            followsSourceTiming: movie.plan.isEmpty
        )
        output.alwaysCopiesSampleData = false
        return output
    }

    /// The chapter track's input: disabled for playback, in the user's language, and listed by the video track as
    /// its chapters.
    private static func chapterInput(
        for writer: AVAssetWriter,
        listedBy video: AVAssetWriterInput
    ) throws -> sending AVAssetWriterInput.SampleBufferReceiver {
        let input = try AVAssetWriterInput(mediaType: .text, outputSettings: nil, sourceFormatHint: ChapterTrack.formatDescription())
        input.marksOutputTrackAsEnabled = false
        input.expectsMediaDataInRealTime = false
        let language = ChapterTrack.language()
        input.languageCode = language.code
        input.extendedLanguageTag = language.tag
        let receiver = writer.inputReceiver(for: input)
        let association = AVAssetTrack.AssociationType.chapterList.rawValue
        if video.canAddTrackAssociation(withTrackOf: input, type: association) {
            video.addTrackAssociation(withTrackOf: input, type: association)
        } else {
            log.notice("the chapter track could not be associated with the video")
        }
        return receiver
    }

    private static func pumpVideo(
        _ provider: sending AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>,
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver,
        length: Double,
        progress: @Sendable (Double) -> Void
    ) async throws {
        var reported = 0.0
        while let sample = try await provider.next() {
            try Task.checkCancellation()
            let time = sample.presentationTimeStamp.seconds
            try await receiver.append(sample)
            let fraction = length > 0 && time.isFinite ? min(max(time / length, 0), 1) : 0
            if fraction - reported >= 0.01 {
                reported = fraction
                progress(fraction * 0.99)
            }
        }
        receiver.finish()
    }

    private static func pumpAudio(
        _ provider: sending AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>?,
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver?
    ) async throws {
        guard let provider, let receiver else { return }
        while let sample = try await provider.next() {
            try Task.checkCancellation()
            try await receiver.append(sample)
        }
        receiver.finish()
    }

    private static func writeChapters(
        _ chapters: [ExportedChapter],
        into receiver: sending AVAssetWriterInput.SampleBufferReceiver?
    ) async throws {
        guard let receiver else { return }
        let format = try ChapterTrack.formatDescription()
        for chapter in chapters {
            try await receiver.append(CMReadySampleBuffer(unsafeBuffer: ChapterTrack.sample(for: chapter, format: format)))
        }
        receiver.finish()
    }

    /// H.264 (High profile) or HEVC at `videoBitRate`, a key frame at least every 2 seconds for quick seeking, in
    /// BT.709 colour like the recordings.
    private static func videoSettings(size: CGSize, frameRate: Double, codec: VideoCodec) -> [String: Any] {
        let width = Int(size.width)
        let height = Int(size.height)
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: VideoExportOptions.videoBitRate(width: width, height: height, frameRate: frameRate, codec: codec),
            AVVideoExpectedSourceFrameRateKey: Int(frameRate.rounded()),
            AVVideoMaxKeyFrameIntervalDurationKey: 2.0,
        ]
        if codec == .h264 {
            compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }
        return [
            AVVideoCodecKey: codec.avCodecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compression,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
    }

    /// What the sound mix is read as: 48 kHz stereo floats.
    private static var pcmSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
    }

    private static var aacSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: VideoExportOptions.audioBitRate,
        ]
    }

    // MARK: GIF

    private static func writeGIF(
        _ trimmed: TrimmedMovie,
        info: MovieInfo,
        plan: ZoomPlan,
        options: VideoExportOptions,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let framePlan = GIFFramePlan(
            duration: trimmed.duration,
            frameRate: options.gif.frameRate,
            sourceWidth: Int(info.size.width),
            sourceHeight: Int(info.size.height),
            maxWidth: options.gif.maxWidth
        )
        let source = ZoomComposition.Source(trackID: trimmed.videoTrack.trackID, size: info.size, orientation: info.orientation)
        let composition = ZoomComposition.make(
            source,
            duration: trimmed.duration,
            plan: plan,
            renderSize: CGSize(width: framePlan.width, height: framePlan.height),
            frameRate: Double(options.gif.frameRate)
        )
        try await GIFExporter.export(
            trimmed.composition,
            videoComposition: composition,
            plan: framePlan,
            to: url,
            options: options.gif,
            progress: progress
        )
    }

    private static func mapped(_ error: any Error) -> any Error {
        if error is CancellationError || error is VideoEditorError || error is RecordingError {
            return error
        }
        if RecordingError.isOutOfSpace(error) {
            return RecordingError.insufficientStorage
        }
        return VideoEditorError.exportFailed(error.localizedDescription)
    }
}
