import CoreGraphics

/// What a pinned capture's controls and context menu ask for.
nonisolated enum PinCommand: Sendable, Equatable {
    case copy
    case save
    case annotate
    case close
    case toggleLock
    case toggleClickThrough
    case setOpacity(CGFloat)
    case changeOpacity(by: CGFloat)
}
