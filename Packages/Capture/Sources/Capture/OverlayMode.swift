/// What a click on the freeze-frame overlay picks (PLAN §7.2, item 3).
nonisolated enum OverlayMode: Sendable, Equatable {
    /// Drag a rectangle; a click picks the window under the pointer as the rectangle.
    case area
    /// Hover highlights the window under the pointer; a click captures it.
    case window
    /// Hover highlights a display; a click captures it.
    case screen
}
