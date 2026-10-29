import Foundation

/// Writes a translated file (PLAN §17) as text, as Markdown with the file's structure, as Markdown with each original
/// above its translation, or as SRT or WebVTT with the cues' timing. A segment without a translation (the translation
/// was cancelled or failed partway) keeps its original, so an export is always complete.
enum DocumentExporter {
    struct Context: Sendable {
        var title: String
        var kind: DocumentKind
        var source: String?
        var target: String
        var provider: String
        /// The header of a WebVTT source.
        var subtitleHeader: String?
    }

    static func data(_ format: DocumentExportFormat, segments: [DocumentSegment], translations: [Int: String], context: Context) -> Data? {
        let text: String? = switch format {
        case .text: plainText(segments, translations: translations)
        case .markdown: markdown(segments, translations: translations, context: context)
        case .bilingualMarkdown: bilingualMarkdown(segments, translations: translations, context: context)
        case .srt: subtitles(segments, translations: translations, as: .srt, header: nil)
        case .vtt: subtitles(segments, translations: translations, as: .vtt, header: context.subtitleHeader)
        case .image: nil
        }
        return text.map { Data($0.utf8) }
    }

    /// The translation, paragraph after paragraph; list items and table rows on consecutive lines.
    static func plainText(_ segments: [DocumentSegment], translations: [Int: String]) -> String {
        joined(segments) { segment in
            segment.verbatim ?? translation(of: segment, in: translations)
        }
    }

    /// The translation with the file's Markdown structure; a PDF gets a heading for each page.
    static func markdown(_ segments: [DocumentSegment], translations: [Int: String], context: Context) -> String {
        let pages = Set(segments.compactMap(\.page))
        var output = ""
        var page: Int?
        for (index, segment) in segments.enumerated() {
            if pages.count > 1, let segmentPage = segment.page, segmentPage != page {
                page = segmentPage
                output += "## Page \(segmentPage)\n\n"
            }
            output += segment.verbatim ?? segment.prefix + translation(of: segment, in: translations)
            output += index == segments.count - 1 ? "\n" : separator(after: segment)
        }
        return output
    }

    /// A title, the languages and provider, then each original as a quote above its translation.
    static func bilingualMarkdown(_ segments: [DocumentSegment], translations: [Int: String], context: Context) -> String {
        let languages = [context.source.map(LanguageCatalog.name(of:)), LanguageCatalog.name(of: context.target)].compactMap(\.self)
            .joined(separator: " → ")
        var lines = ["# \(context.title)", "", "*\(languages) · \(context.provider)*"]
        let pages = Set(segments.compactMap(\.page))
        var page: Int?
        for segment in segments {
            if pages.count > 1, let segmentPage = segment.page, segmentPage != page {
                page = segmentPage
                lines += ["", "## Page \(segmentPage)"]
            }
            lines.append("")
            if let verbatim = segment.verbatim {
                lines.append(verbatim)
                continue
            }
            lines += segment.text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }
            lines.append("")
            lines.append(translations[segment.id] ?? "*(not translated)*")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The cues with their timing and the translated text.
    static func subtitles(
        _ segments: [DocumentSegment],
        translations: [Int: String],
        as format: SubtitleFormat,
        header: String?
    ) -> String {
        let cues = segments.compactMap { segment in
            segment.cue.map { (cue: $0, text: translation(of: segment, in: translations)) }
        }
        return format == .srt ? SubtitleFile.srt(cues) : SubtitleFile.vtt(cues, header: header)
    }

    /// "notes.ja.md": the file's name, the target language and the format's extension.
    static func suggestedFileName(for url: URL?, format: DocumentExportFormat, target: String) -> String {
        let base = url?.deletingPathExtension().lastPathComponent ?? "Translation"
        return "\(base).\(target).\(format.fileExtension)"
    }

    private static func translation(of segment: DocumentSegment, in translations: [Int: String]) -> String {
        translations[segment.id] ?? segment.text
    }

    private static func separator(after segment: DocumentSegment) -> String {
        segment.endsBlock ? "\n\n" : "\n"
    }

    private static func joined(_ segments: [DocumentSegment], _ text: (DocumentSegment) -> String) -> String {
        var output = ""
        for (index, segment) in segments.enumerated() {
            output += text(segment)
            output += index == segments.count - 1 ? "\n" : separator(after: segment)
        }
        return output
    }
}
