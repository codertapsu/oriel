import Foundation

/// What a render leaves out or adds; the defaults produce the exported image.
nonisolated struct RenderOptions: Equatable, Sendable {
    /// The crop tool's view: the whole base image, without padding or background.
    var showsUncroppedImage = false
    /// Items not to draw, such as the label being edited in the text overlay.
    var hiddenItems: Set<UUID> = []
    /// An opaque fill under everything, for formats without transparency (JPEG).
    var matte: RGBAColor?
}
