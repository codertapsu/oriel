import CoreGraphics

/// One piece of text as Vision reported it, before it becomes an `OCRBlock`: the box is still normalized with a
/// bottom-left origin. Keeping Vision's types out of here lets `OCRLayout` be tested with plain values.
struct RecognizedRegion: Equatable, Sendable {
    var text: String
    /// Normalized (0…1), bottom-left origin, as Vision reports it.
    var normalizedBox: CGRect
    var confidence: Float
    var lineCount: Int
}
