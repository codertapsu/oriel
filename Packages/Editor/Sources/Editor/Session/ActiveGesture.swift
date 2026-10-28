import CoreGraphics
import Foundation

/// A pointer drag in progress: what `EditorSession.continueGesture(to:modifiers:)` updates.
nonisolated enum ActiveGesture: Sendable {
    /// Drawing a new arrow, line, box or region from `start`.
    case creating(id: UUID, start: CGPoint)
    /// Drawing a new pen or highlighter stroke.
    case drawing(id: UUID)
    /// Dragging items (the selection, or a step marker just placed) from where they were.
    case moving(originals: [UUID: AnnotationItem], start: CGPoint)
    /// Dragging one handle of `original`.
    case resizing(original: AnnotationItem, handle: SelectionHandle)
    /// Rubber-band selection; `base` was selected before (Shift adds to it).
    case marquee(start: CGPoint, base: Set<UUID>)
    /// Crop tool: a new crop rect, moving the crop rect, or one of its handles.
    case cropNew(start: CGPoint, previous: CGRect)
    case cropMove(original: CGRect, start: CGPoint)
    case cropResize(original: CGRect, handle: SelectionHandle)
}
