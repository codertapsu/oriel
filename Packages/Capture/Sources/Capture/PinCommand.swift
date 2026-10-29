import CoreGraphics

/// What a pinned capture's controls, keys, context menu and status-menu submenu ask for.
nonisolated enum PinCommand: Sendable, Equatable {
    case copy
    case save
    case annotate
    case close
    case bringToFront
    case toggleLock
    case toggleClickThrough
    case toggleBorder
    case setOpacity(CGFloat)
    case changeOpacity(by: CGFloat)
    case zoomIn
    case zoomOut
    /// The capture's own point size.
    case actualSize
    /// Zooms by `factor`, keeping `anchor` (screen coordinates, Cocoa) in place.
    case zoom(by: CGFloat, anchor: CGPoint)
    /// Moves the pin by whole points, unless its position is locked.
    case move(dx: CGFloat, dy: CGFloat)
}
