import CoreGraphics

/// One block of an open translation: the OCR text and box, and the translation once it arrives.
struct TranslationBlock: Identifiable, Equatable, Sendable {
    let id: Int
    var source: String
    /// Image pixels, top-left origin. Nil for text only AI Vision found, which has no box.
    let box: CGRect?
    let lineCount: Int
    var translation: String?
}
