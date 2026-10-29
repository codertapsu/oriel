import CoreGraphics
import Foundation

/// A bitmap drawn into `rect` (image space). Smart Move makes two of them for each object it lifts: the object
/// itself (`AnnotationItem.image`), which moves like any annotation, and the background that fills the hole it leaves
/// (`AnnotationItem.patch`), which stays with the image. Simplify erases text lines with patches too.
nonisolated struct ImageLayer: Codable, Sendable, Equatable {
    /// What the pixels were found as, for VoiceOver and the review counts.
    enum Source: String, Codable, Sendable {
        case text
        case object
        case region
    }

    var id: UUID
    var asset: ImageAsset
    var rect: CGRect
    var source: Source

    init(id: UUID = UUID(), asset: ImageAsset, rect: CGRect, source: Source) {
        self.id = id
        self.asset = asset
        self.rect = rect
        self.source = source
    }
}
