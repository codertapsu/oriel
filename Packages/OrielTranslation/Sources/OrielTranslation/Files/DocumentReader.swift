import AppKit
import ImageIO
import OrielCore
import PDFKit

/// Reads a file's text for translation (PLAN §17), off the main thread: text files and Markdown as UTF-8, UTF-16 or
/// Latin 1; RTF, RTFD, Word and OpenDocument through `NSAttributedString`; HTML with `HTMLTextExtractor`; subtitles
/// with their timing; images with OCR; PDFs page by page, PDFKit's text where a page has it and OCR of the rendered
/// page where it has none (a scan).
enum DocumentReader {
    enum ReadError: LocalizedError, Equatable {
        case unreadable(String)
        case locked
        case tooLarge
        case empty

        var errorDescription: String? {
            switch self {
            case let .unreadable(name): "Oriel couldn't read “\(name)”."
            case .locked: "This PDF is protected with a password. Open it in Preview, export an unprotected copy and translate that."
            case .tooLarge: "This file is too large to translate (more than 50 MB of text)."
            case .empty: "This file has no text to translate."
            }
        }
    }

    /// Text files over this size are refused: at that length a translation is better done another way.
    static let maximumTextBytes = 50_000_000
    /// Scanned pages are rendered with this many pixels on their long edge for OCR.
    static let scanPixels: CGFloat = 3000
    /// Images are read at most this large.
    static let maximumImagePixels = 8000

    /// The file's text as parts: one for most files, one per page for PDFs. `languages` are OCR hints.
    static func parts(
        of url: URL,
        kind: DocumentKind,
        recognizer: any TextRecognizing,
        languages: [String]
    ) -> AsyncThrowingStream<DocumentPart, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    switch kind {
                    case .pdf:
                        try await readPDF(url, recognizer: recognizer, languages: languages) { continuation.yield($0) }
                    case .image:
                        try await continuation.yield(readImage(url, recognizer: recognizer, languages: languages))
                    default:
                        try continuation.yield(readText(url, kind: kind))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Text

    static func readText(_ url: URL, kind: DocumentKind) throws -> DocumentPart {
        if case let .richText(format) = kind {
            return try DocumentPart(segments: richTextSegments(url, format: format))
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values?.fileSize, size > maximumTextBytes {
            throw ReadError.tooLarge
        }
        let data = try Data(contentsOf: url)
        let charset = kind == .html ? TextDecoding.declaredHTMLCharset(in: data) : nil
        let text = TextDecoding.string(from: data, declaredCharset: charset)
        switch kind {
        case .markdown:
            return DocumentPart(segments: MarkdownSegmenter.segments(text))
        case .html:
            return DocumentPart(segments: HTMLTextExtractor.segments(text))
        case .subtitles:
            let parsed = SubtitleFile.parse(text)
            let segments = parsed.cues.enumerated().map { index, cue in
                DocumentSegment(id: index + 1, text: cue.plainText, cue: cue)
            }
            return DocumentPart(segments: segments, subtitleHeader: parsed.header)
        default:
            return DocumentPart(segments: PlainTextSegmenter.segments(text))
        }
    }

    /// Paragraphs of a rich text file. Lists come with their markers in the text ("•\t"); those become Markdown
    /// markers. Attachments and empty paragraphs go.
    static func richTextSegments(_ url: URL, format: RichTextFormat) throws -> [DocumentSegment] {
        let type: NSAttributedString.DocumentType = switch format {
        case .rtf: .rtf
        case .rtfd: .rtfd
        case .docx: .officeOpenXML
        case .doc: .docFormat
        case .odt: .openDocument
        }
        let string: NSAttributedString
        do {
            string = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil)
        } catch {
            throw ReadError.unreadable(url.lastPathComponent)
        }
        return richTextSegments(string.string)
    }

    static func richTextSegments(_ text: String) -> [DocumentSegment] {
        let paragraphs = text.replacingOccurrences(of: "\u{FFFC}", with: "")
            .split(whereSeparator: { $0 == "\n" || $0 == "\u{2029}" || $0 == "\r\n" || $0 == "\r" })
            .map { $0.replacingOccurrences(of: "\u{2028}", with: "\n").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var segments: [DocumentSegment] = []
        for paragraph in paragraphs {
            let (prefix, text) = listMarker(in: paragraph)
            let isItem = !prefix.isEmpty
            if isItem, !segments.isEmpty, !segments[segments.count - 1].prefix.isEmpty {
                segments[segments.count - 1].endsBlock = false
            }
            segments.append(DocumentSegment(id: segments.count + 1, text: text, prefix: prefix))
        }
        return segments
    }

    /// `•\tItem` → (`- `, `Item`); `3.\tItem` → (`3. `, `Item`).
    private static func listMarker(in paragraph: String) -> (String, String) {
        guard let tab = paragraph.firstIndex(of: "\t"), paragraph.distance(from: paragraph.startIndex, to: tab) <= 4 else {
            return ("", paragraph)
        }
        let marker = paragraph[..<tab].trimmingCharacters(in: .whitespaces)
        let rest = paragraph[paragraph.index(after: tab)...].trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return ("", paragraph) }
        if ["•", "◦", "▪", "‣", "⁃", "–", "-", "*", "·"].contains(marker) {
            return ("- ", rest)
        }
        let digits = marker.prefix { $0.isNumber }
        if !digits.isEmpty, marker.dropFirst(digits.count) == "." || marker.dropFirst(digits.count) == ")" {
            return ("\(digits). ", rest)
        }
        return ("", paragraph)
    }

    // MARK: - Images

    static func readImage(_ url: URL, recognizer: any TextRecognizing, languages: [String]) async throws -> DocumentPart {
        guard let image = loadImage(url) else { throw ReadError.unreadable(url.lastPathComponent) }
        let blocks = try await recognizer.recognize(image, mode: .document, languages: languages)
        let segments = blocks.map { DocumentSegment(id: $0.id, text: $0.text) }
        return DocumentPart(segments: segments, image: image, blocks: blocks, usedOCR: true)
    }

    /// The image upright (EXIF orientation applied), at most `maximumImagePixels` on its long edge.
    static func loadImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maximumImagePixels
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maximumImagePixels
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maximumImagePixels, max(width, height)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - PDF

    private static func readPDF(
        _ url: URL,
        recognizer: any TextRecognizing,
        languages: [String],
        yield: (DocumentPart) -> Void
    ) async throws {
        guard let document = PDFDocument(url: url) else { throw ReadError.unreadable(url.lastPathComponent) }
        if document.isLocked, !document.unlock(withPassword: "") {
            throw ReadError.locked
        }
        let count = document.pageCount
        var nextID = 1
        for index in 0 ..< count {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            var part: DocumentPart
            if let texts = textParagraphs(of: page) {
                part = DocumentPart(segments: texts.map { DocumentSegment(id: 0, text: $0) })
            } else if let image = render(page) {
                let blocks = try await recognizer.recognize(image, mode: .document, languages: languages)
                part = DocumentPart(segments: blocks.map { DocumentSegment(id: 0, text: $0.text) }, usedOCR: true)
            } else {
                part = DocumentPart(segments: [])
            }
            part.segments = part.segments.map { segment in
                defer { nextID += 1 }
                return DocumentSegment(id: nextID, text: segment.text, page: index + 1)
            }
            part.page = index + 1
            part.pageCount = count
            yield(part)
        }
    }

    /// The page's paragraphs from its text layer, or nil when it has hardly any text (a scan).
    static func textParagraphs(of page: PDFPage) -> [String]? {
        guard let text = page.string, text.count(where: \.isLetter) >= 16 else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let lines = (page.selection(for: bounds)?.selectionsByLine() ?? []).compactMap { line -> TextLine? in
            guard let string = line.string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else { return nil }
            let box = line.bounds(for: page)
            // PDF space has its origin at the bottom left.
            return TextLine(text: string, box: CGRect(x: box.minX, y: bounds.maxY - box.maxY, width: box.width, height: box.height))
        }
        guard !lines.isEmpty else { return PlainTextSegmenter.paragraphs(text) }
        return TextLineGrouping.sequentialParagraphs(lines).map { group in LineJoiner.join(group.map { lines[$0].text }) }
    }

    /// The page as an image for OCR, upright, `scanPixels` on its long edge.
    static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .cropBox)
        let rotated = abs(page.rotation) % 180 == 90
        let size = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let factor = scanPixels / max(size.width, size.height)
        let thumbnail = page.thumbnail(of: CGSize(width: size.width * factor, height: size.height * factor), for: .cropBox)
        var rect = CGRect(origin: .zero, size: thumbnail.size)
        return thumbnail.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
