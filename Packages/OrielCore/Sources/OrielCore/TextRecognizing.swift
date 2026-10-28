import CoreGraphics

/// On-device OCR. The OCR package's `VisionTextRecognizer` implements it; Capture ("Copy Text") and
/// Translation consume it.
public protocol TextRecognizing: Sendable {
    /// `languages` are BCP 47 hints; empty means automatic.
    func recognize(_ image: CGImage, mode: OCRMode, languages: [String]) async throws -> [OCRBlock]
}
