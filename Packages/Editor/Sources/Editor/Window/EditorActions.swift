/// The window controller's actions, handed to the SwiftUI bars so they stay free of AppKit.
struct EditorActions {
    var copy: () -> Void
    var save: () -> Void
    var export: () -> Void
    var quickLook: () -> Void
    var upload: () -> Void
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var zoomToFit: () -> Void
    var actualSize: () -> Void
    var dragPayload: () -> DragPayload?
    var dragDelivered: () -> Void
}
