import Foundation
import UniformTypeIdentifiers

/// What kind of file is being translated (PLAN §17), which decides how its text is read and what it exports to.
enum DocumentKind: Hashable, Sendable {
    /// A picture: OCR, then the translation drawn over it like Translate Area.
    case image
    /// PDFKit's text where a page has it; scanned pages are rendered and read with OCR.
    case pdf
    case plainText
    case markdown
    /// Read through `NSAttributedString`.
    case richText(RichTextFormat)
    /// Read by Oriel's own HTML reader: no WebKit, so nothing is loaded from the network.
    case html
    /// Cues keep their timing.
    case subtitles(SubtitleFormat)

    /// Routes a file by its extension, then by what its type conforms to; nil for files Oriel cannot translate. The file
    /// is only asked for its type when the extension says nothing.
    static func of(_ url: URL) -> DocumentKind? {
        if let kind = of(fileExtension: url.pathExtension, type: nil) {
            return kind
        }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        return of(fileExtension: url.pathExtension, type: type ?? UTType(filenameExtension: url.pathExtension))
    }

    static func of(fileExtension: String, type: UTType?) -> DocumentKind? {
        switch fileExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp": return .image
        case "pdf": return .pdf
        case "txt", "text", "log": return .plainText
        case "md", "markdown", "mdown", "mkd", "mkdn": return .markdown
        case "rtf": return .richText(.rtf)
        case "rtfd": return .richText(.rtfd)
        case "docx": return .richText(.docx)
        case "doc": return .richText(.doc)
        case "odt": return .richText(.odt)
        case "html", "htm", "xhtml": return .html
        case "srt": return .subtitles(.srt)
        case "vtt", "webvtt": return .subtitles(.vtt)
        default: break
        }
        guard let type else { return nil }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .pdf) {
            return .pdf
        }
        if type.conforms(to: .html) {
            return .html
        }
        if type.conforms(to: .rtfd) || type.conforms(to: .flatRTFD) {
            return .richText(.rtfd)
        }
        if type.conforms(to: .rtf) {
            return .richText(.rtf)
        }
        if type.conforms(to: .plainText) {
            return .plainText
        }
        return nil
    }

    /// What the open panel offers.
    static let openableTypes: [UTType] = {
        let extra = ["md", "markdown", "docx", "doc", "odt", "srt", "vtt"].compactMap { UTType(filenameExtension: $0) }
        return [.image, .pdf, .plainText, .rtf, .rtfd, .flatRTFD, .html] + extra
    }()

    /// "Markdown", "Subtitles (SRT)".
    var title: String {
        switch self {
        case .image: "Image"
        case .pdf: "PDF"
        case .plainText: "Text"
        case .markdown: "Markdown"
        case let .richText(format): format.title
        case .html: "Web page"
        case let .subtitles(format): "Subtitles (\(format.title))"
        }
    }

    /// What one segment is called, for progress: "12 of 40 cues".
    func count(_ number: Int) -> String {
        let (one, many) = switch self {
        case .image: ("block", "blocks")
        case .subtitles: ("cue", "cues")
        default: ("paragraph", "paragraphs")
        }
        return "\(number.formatted()) \(number == 1 ? one : many)"
    }

    /// The exports that make sense for the kind: subtitles keep their timing, images their pixels.
    var exportFormats: [DocumentExportFormat] {
        switch self {
        case .image: [.image, .text, .markdown]
        case .subtitles: [.srt, .vtt, .text]
        default: [.text, .markdown, .bilingualMarkdown]
        }
    }
}
