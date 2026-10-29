import CoreGraphics

/// The text Translate Under Cursor found under the pointer, and where it is in global points (top-left origin).
struct CursorRecognition: Equatable, Sendable {
    let text: String
    let region: CGRect
}
