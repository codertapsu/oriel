import UniformTypeIdentifiers

/// What a translated file can be saved as (PLAN §17).
enum DocumentExportFormat: String, CaseIterable, Identifiable, Sendable {
    /// The translation alone, one paragraph after another.
    case text
    /// The translation with the structure the file had: headings, lists, quotes, code; page headings for PDFs.
    case markdown
    /// Each paragraph's original as a quote, then its translation.
    case bilingualMarkdown
    case srt
    case vtt
    /// The image with the translation drawn over it.
    case image

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .text: "Text"
        case .markdown: "Markdown"
        case .bilingualMarkdown: "Markdown with the Original"
        case .srt: "SRT Subtitles"
        case .vtt: "WebVTT Subtitles"
        case .image: "PNG Image"
        }
    }

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .markdown, .bilingualMarkdown: "md"
        case .srt: "srt"
        case .vtt: "vtt"
        case .image: "png"
        }
    }

    var contentType: UTType {
        switch self {
        case .text: .plainText
        case .markdown, .bilingualMarkdown: UTType(filenameExtension: "md") ?? .plainText
        case .srt: UTType(filenameExtension: "srt") ?? .plainText
        case .vtt: UTType(filenameExtension: "vtt") ?? .plainText
        case .image: .png
        }
    }
}
