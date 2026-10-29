import CoreGraphics

/// The frames of the actions that start from where the window is: moving it to another display and making it a step
/// smaller or larger. Pure, like `TileLayout`.
nonisolated enum TileMotion {
    /// `window` on `target` with its size (shrunk to fit) and its place: a window against the left edge stays against it,
    /// a centered one stays centered, as the Window menu's Move to Display does. Used for windows that are not in a
    /// layout; a tiled window takes the same layout on the other display instead.
    static func moved(_ window: CGRect, from source: DisplayGeometry, to target: DisplayGeometry, options: TilingOptions) -> TilePlacement {
        let from = source.usableFrame(gap: options.gap)
        let to = target.usableFrame(gap: options.gap)
        let width = min(window.width, to.width)
        let height = min(window.height, to.height)
        let horizontal = keepPlace(window.minX, window.width, from: from.minX, from.width, to: to.minX, to.width, newLength: width)
        let vertical = keepPlace(window.minY, window.height, from: from.minY, from.height, to: to.minY, to.height, newLength: height)
        return TilePlacement(
            frame: CGRect(x: horizontal.start, y: vertical.start, width: width, height: height),
            horizontal: horizontal.anchor,
            vertical: vertical.anchor
        )
    }

    /// `window` one step larger or smaller: `TilingOptions.resizeStep` of the screen in each direction. Edges the window
    /// shares with the screen stay; otherwise the window keeps its center. It stays on the screen, never grows past it
    /// and never shrinks below `TilingOptions.minimumFraction` of it. Nil when nothing would change.
    static func resized(_ window: CGRect, on display: DisplayGeometry, larger: Bool, options: TilingOptions) -> TilePlacement? {
        let area = display.usableFrame(gap: options.gap)
        let horizontal = step(window.minX, window.width, within: area.minX, area.width, larger: larger)
        let vertical = step(window.minY, window.height, within: area.minY, area.height, larger: larger)
        let frame = CGRect(x: horizontal.start, y: vertical.start, width: horizontal.length, height: vertical.length)
        guard !TileLayout.isSame(frame, window) else { return nil }
        return TilePlacement(frame: frame, horizontal: horizontal.anchor, vertical: vertical.anchor)
    }

    /// Along one axis: the same share of the free space before the window, on the target.
    private static func keepPlace(
        _ start: CGFloat,
        _ length: CGFloat,
        from origin: CGFloat,
        _ span: CGFloat,
        to targetOrigin: CGFloat,
        _ targetSpan: CGFloat,
        newLength: CGFloat
    ) -> (start: CGFloat, anchor: TilePlacement.Anchor) {
        let free = span - length
        let share = free > TileLayout.tolerance ? TileLayout.clamp((start - origin) / free, lower: 0, upper: 1) : 0.5
        let anchor: TilePlacement.Anchor = share < 0.01 ? .start : share > 0.99 ? .end : .center
        return ((targetOrigin + share * (targetSpan - newLength)).rounded(), anchor)
    }

    /// Along one axis: the new start and length after one size step, and the edge that stayed.
    private static func step(
        _ start: CGFloat,
        _ length: CGFloat,
        within areaStart: CGFloat,
        _ areaLength: CGFloat,
        larger: Bool
    ) -> (start: CGFloat, length: CGFloat, anchor: TilePlacement.Anchor) {
        let delta = (areaLength * TilingOptions.resizeStep).rounded()
        let minimum = (areaLength * TilingOptions.minimumFraction).rounded()
        let newLength = if larger {
            max(length, min(length + delta, areaLength))
        } else {
            length > minimum ? max(length - delta, minimum) : length
        }
        let end = start + length
        let touchesStart = abs(start - areaStart) <= TileLayout.tolerance
        let touchesEnd = abs(end - (areaStart + areaLength)) <= TileLayout.tolerance
        let anchor: TilePlacement.Anchor = switch (touchesStart, touchesEnd) {
        case (true, false): .start
        case (false, true): .end
        default: .center
        }
        let wanted = switch anchor {
        case .start: start
        case .end: end - newLength
        case .center: start + (length - newLength) / 2
        }
        let placed = TileLayout.clamp(wanted, lower: areaStart, upper: areaStart + areaLength - newLength)
        return (placed.rounded(), newLength.rounded(), anchor)
    }
}
