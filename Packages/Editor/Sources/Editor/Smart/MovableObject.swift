/// An object Smart Move can lift out of the screenshot: its pixels as a layer the user can move or delete, and the
/// background that fills the hole it leaves.
nonisolated struct MovableObject: Sendable, Equatable {
    let layer: ImageLayer
    let patch: ImageLayer

    var source: ImageLayer.Source {
        layer.source
    }
}
