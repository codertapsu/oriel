import CoreGraphics

/// One block of recognized text: a paragraph in `.document` mode, a line in `.fast` mode.
public struct OCRBlock: Codable, Sendable, Hashable, Identifiable {
    public let id: Int
    public var text: String
    /// In the image's pixels, top-left origin (converted once from Vision's normalized bottom-left boxes).
    public var boundingBox: CGRect
    public var confidence: Float
    public var lineCount: Int
    /// BCP 47 code, when Vision or NLLanguageRecognizer could tell.
    public var language: String?

    public init(id: Int, text: String, boundingBox: CGRect, confidence: Float, lineCount: Int = 1, language: String? = nil) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.lineCount = lineCount
        self.language = language
    }
}
