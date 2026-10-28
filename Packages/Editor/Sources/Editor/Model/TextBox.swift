import CoreGraphics
import Foundation

/// A text label whose top-left corner is `origin`, in image space. It grows with its text; lines break only at
/// newlines the user typed.
nonisolated struct TextBox: Codable, Sendable, Equatable {
    var id: UUID
    var origin: CGPoint
    var text: String
    var color: RGBAColor
    var fontSize: CGFloat

    init(id: UUID = UUID(), origin: CGPoint, text: String, color: RGBAColor, fontSize: CGFloat) {
        self.id = id
        self.origin = origin
        self.text = text
        self.color = color
        self.fontSize = fontSize
    }

    /// The laid-out text's rect, the same one the renderer fills.
    var frame: CGRect {
        CGRect(origin: origin, size: TextLayout.size(of: text, fontSize: fontSize))
    }
}
