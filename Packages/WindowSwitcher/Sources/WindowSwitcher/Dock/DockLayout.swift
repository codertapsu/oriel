import CoreGraphics
import OrielCore

/// The Dock as it is laid out now (PLAN §7.1.12): its icons in order, its list's frame and the edge of the screen it is
/// on. Read again after anything that can move the icons; Accessibility does not say when they move.
nonisolated struct DockLayout: Sendable, Equatable {
    enum Edge: Sendable, Equatable {
        case bottom
        case left
        case right
    }

    var items: [DockItem]
    /// The `AXList`'s frame, global CoreGraphics coordinates.
    var frame: CGRect
    var edge: Edge

    /// A horizontal Dock is at the bottom; a vertical one on the left or right of the display that holds most of it.
    static func edge(isVertical: Bool, frame: CGRect, displays: [CGRect]) -> Edge {
        guard isVertical else { return .bottom }
        guard let index = ScreenGeometry.bestDisplay(for: frame, among: displays) else { return .left }
        return frame.midX < displays[index].midX ? .left : .right
    }

    /// The edge an icon read on its own is nearest, of the left, right and bottom of its display, for a preview shown
    /// before the layout has been read.
    static func edge(nearest itemFrame: CGRect, on display: CGRect) -> Edge {
        let distances: [(Edge, CGFloat)] = [
            (.bottom, display.maxY - itemFrame.maxY),
            (.left, itemFrame.minX - display.minX),
            (.right, display.maxX - itemFrame.maxX),
        ]
        return distances.min { $0.1 < $1.1 }?.0 ?? .bottom
    }

    /// Whether the Dock was out, on one display, when it was read: a Dock that hides itself, or that a full-screen app
    /// hides, reads beyond the display's edge, and one sliding in or out reads across it. Its icons are not where they
    /// will be seen then.
    func isOnScreen(displays: [CGRect]) -> Bool {
        let area = items.reduce(frame) { $0.union($1.frame) }
        guard let index = ScreenGeometry.bestDisplay(for: area, among: displays) else { return false }
        return displays[index].insetBy(dx: -1, dy: -1).contains(area)
    }

    /// Where an item read on its own (the hovered one) is among these: the app item with its URL under it, else the first
    /// with its URL.
    func index(of item: DockItem) -> Int? {
        items.firstIndex { $0.kind == .application && $0.url == item.url && $0.frame.intersects(item.frame) }
            ?? items.firstIndex { $0.kind == .application && $0.url == item.url }
    }
}
