import CoreGraphics

/// One line of text and where it is, top-left origin (OCR pixels, screen points or PDF points flipped).
struct TextLine: Equatable, Sendable {
    let text: String
    let box: CGRect
}
