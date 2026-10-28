import CoreGraphics

/// What a key press or a toolbar button asks an editor window to do.
nonisolated enum EditorCommand: Equatable, Sendable {
    case tool(EditorTool)
    case delete
    case nudge(dx: CGFloat, dy: CGFloat)
    /// Escape.
    case cancel
    /// Return or Enter.
    case confirm
    case undo
    case redo
    /// Copies the flattened image.
    case copy
    /// Saves the editable `.oriel` bundle.
    case save
    case export
    /// Shows the flattened image in Quick Look, or closes the preview.
    case quickLook
    case selectAll
    case zoomIn
    case zoomOut
    case zoomToFit
    case actualSize
    case close
}
