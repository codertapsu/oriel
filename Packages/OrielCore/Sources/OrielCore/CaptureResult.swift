import CoreGraphics
import Foundation

/// One finished capture, handed from Capture to the editor, translation, upload, pins and history.
public struct CaptureResult: Sendable, Identifiable {
    public let id: UUID
    public let image: CGImage
    public let kind: CaptureKind
    /// The captured area in global CoreGraphics coordinates (points, top-left origin). Zero for imports.
    public let rect: CGRect
    /// Pixels per point of the source display (2 on Retina).
    public let scale: CGFloat
    public let date: Date
    public let windowTitle: String?
    public let appName: String?

    public init(
        id: UUID = UUID(),
        image: CGImage,
        kind: CaptureKind,
        rect: CGRect,
        scale: CGFloat,
        date: Date = Date(),
        windowTitle: String? = nil,
        appName: String? = nil
    ) {
        self.id = id
        self.image = image
        self.kind = kind
        self.rect = rect
        self.scale = scale
        self.date = date
        self.windowTitle = windowTitle
        self.appName = appName
    }

    /// The image's size in points, which is what it should be shown at.
    public var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / max(scale, 1), height: CGFloat(image.height) / max(scale, 1))
    }
}
