import CoreGraphics
import OrielCore

/// What `DocumentReader` delivers: the whole file at once, or a PDF one page at a time.
struct DocumentPart: Sendable {
    var segments: [DocumentSegment]
    /// The page, from 1, and how many there are; nil for files without pages.
    var page: Int?
    var pageCount: Int?
    /// WebVTT's header, kept for a WebVTT export.
    var subtitleHeader: String?
    /// An image file, for the translated image.
    var image: CGImage?
    /// The OCR blocks of an image file, whose ids are the segments'.
    var blocks: [OCRBlock] = []
    /// Whether the text was read with OCR (an image, or a scanned PDF page).
    var usedOCR = false
}
