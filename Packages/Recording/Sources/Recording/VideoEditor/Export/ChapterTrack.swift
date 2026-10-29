import AVFoundation
import CoreMedia

/// A QuickTime chapter track (PLAN §17): a text track of 3GPP timed text ('tx3g'), one sample per chapter, that
/// the video track lists as its chapters (`AVAssetTrack.AssociationType.chapterList`). QuickTime Player, IINA and
/// ffmpeg read it from MPEG-4 and QuickTime files alike; the older QuickTime text format is refused by
/// AVAssetWriter without a full style description (macOS 27.0.1).
nonisolated enum ChapterTrack {
    /// The description of the chapter samples: 3GPP text with a plain default style, which players ignore for
    /// chapters but the format requires.
    static func formatDescription() throws -> CMFormatDescription {
        let white: [String: Int] = [
            kCMTextFormatDescriptionColor_Red as String: 255,
            kCMTextFormatDescriptionColor_Green as String: 255,
            kCMTextFormatDescriptionColor_Blue as String: 255,
            kCMTextFormatDescriptionColor_Alpha as String: 255,
        ]
        let black: [String: Int] = [
            kCMTextFormatDescriptionColor_Red as String: 0,
            kCMTextFormatDescriptionColor_Green as String: 0,
            kCMTextFormatDescriptionColor_Blue as String: 0,
            kCMTextFormatDescriptionColor_Alpha as String: 255,
        ]
        let style: [String: Any] = [
            kCMTextFormatDescriptionStyle_StartChar as String: 0,
            kCMTextFormatDescriptionStyle_EndChar as String: 0,
            kCMTextFormatDescriptionStyle_Font as String: 1,
            kCMTextFormatDescriptionStyle_FontFace as String: 0,
            kCMTextFormatDescriptionStyle_ForegroundColor as String: white,
            kCMTextFormatDescriptionStyle_FontSize as String: 12,
        ]
        let extensions: [String: Any] = [
            kCMTextFormatDescriptionExtension_DisplayFlags as String: 0,
            kCMTextFormatDescriptionExtension_BackgroundColor as String: black,
            kCMTextFormatDescriptionExtension_DefaultTextBox as String: [
                kCMTextFormatDescriptionRect_Top as String: 0,
                kCMTextFormatDescriptionRect_Left as String: 0,
                kCMTextFormatDescriptionRect_Bottom as String: 0,
                kCMTextFormatDescriptionRect_Right as String: 0,
            ],
            kCMTextFormatDescriptionExtension_DefaultStyle as String: style,
            kCMTextFormatDescriptionExtension_HorizontalJustification as String: 0,
            kCMTextFormatDescriptionExtension_VerticalJustification as String: 0,
            kCMTextFormatDescriptionExtension_FontTable as String: ["1": "Sans-Serif"],
        ]
        var description: CMFormatDescription?
        let status = CMFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            mediaType: kCMMediaType_Text,
            mediaSubType: kCMTextFormatType_3GText,
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &description
        )
        guard status == noErr, let description else {
            throw VideoEditorError.exportFailed("The chapter track could not be described (\(status)).")
        }
        return description
    }

    /// One chapter's sample: its title as UTF-8 after a 16-bit big-endian length, shown from `start` for
    /// `duration` seconds.
    static func sample(for chapter: ExportedChapter, format: CMFormatDescription) throws -> CMSampleBuffer {
        let title = Array(chapter.title.utf8.prefix(Int(UInt16.max)))
        var bytes = [UInt8(title.count >> 8), UInt8(title.count & 0xFF)]
        bytes.append(contentsOf: title)
        var block: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: bytes.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: bytes.count,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block
        )
        guard status == noErr, let block else {
            throw VideoEditorError.exportFailed("A chapter could not be written (\(status)).")
        }
        status = bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferReplaceDataBytes(with: base, blockBuffer: block, offsetIntoDestination: 0, dataLength: raw.count)
        }
        guard status == noErr else {
            throw VideoEditorError.exportFailed("A chapter could not be written (\(status)).")
        }
        let timing = CMSampleTimingInfo(
            duration: CMTime(seconds: chapter.duration, preferredTimescale: 600),
            presentationTimeStamp: CMTime(seconds: chapter.start, preferredTimescale: 600),
            decodeTimeStamp: .invalid
        )
        return try CMSampleBuffer(
            dataBuffer: block,
            formatDescription: format,
            numSamples: 1,
            sampleTimings: [timing],
            sampleSizes: [bytes.count]
        )
    }

    /// The language the chapter titles are taken to be in: the user's first preferred language, as the ISO 639-2
    /// code QuickTime stores and the BCP 47 tag AVFoundation matches players' languages against.
    static func language(preferred: [String] = Locale.preferredLanguages) -> (code: String, tag: String?) {
        guard let first = preferred.first,
              let code = Locale.Language(identifier: first).languageCode?.identifier(.alpha3)
        else {
            return ("und", nil)
        }
        return (code, first)
    }

    /// The chapters of the movie at `url`, or nil when it has none.
    @concurrent
    static func chapters(ofMovieAt url: URL) async throws -> [ExportedChapter]? {
        try await chapters(of: AVURLAsset(url: url))
    }

    /// The chapters stored in `asset`, in the user's languages if it has several, or nil when it has none.
    @concurrent
    static func chapters(of asset: AVAsset) async throws -> [ExportedChapter]? {
        let locales = try await asset.load(.availableChapterLocales)
        guard !locales.isEmpty else { return nil }
        var groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: Locale.preferredLanguages)
        if groups.isEmpty {
            groups = try await asset.loadChapterMetadataGroups(withTitleLocale: locales[0], containingItemsWithCommonKeys: [])
        }
        var chapters: [ExportedChapter] = []
        for group in groups {
            var title = ""
            for item in group.items {
                if let text = try await item.load(.stringValue) {
                    title = text
                    break
                }
            }
            chapters.append(ExportedChapter(start: group.timeRange.start.seconds, duration: group.timeRange.duration.seconds, title: title))
        }
        return chapters.isEmpty ? nil : chapters
    }
}
