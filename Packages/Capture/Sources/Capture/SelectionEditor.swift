import CoreGraphics
import OrielCore

/// The area selection on one display, as the mouse and keyboard edit it (PLAN §7.2, item 4). Pure, so the
/// precision rules are unit-tested: the selection stays on its display, every edge sits on the display's pixel grid,
/// arrows move it by whole pixels, Option-arrows resize it, Space-drag moves it while drawing, and edges snap to
/// nearby window edges unless ⌘ is held.
nonisolated struct SelectionEditor: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case idle
        /// Drawing a new rectangle from `anchor` to the pointer at `current` (before snapping).
        case drawing(anchor: CGPoint, current: CGPoint)
        /// Moving the whole selection: the drag began at `start`, when the selection was `original`.
        case moving(start: CGPoint, original: CGRect)
        /// Dragging one handle of `original`.
        case resizing(SelectionHandle, original: CGRect)
    }

    /// The shortest drag (points) that draws a rectangle; anything shorter is a click.
    static let minimumDrag: CGFloat = 3

    /// The display, in global CoreGraphics points.
    let bounds: CGRect
    /// Pixels per point of the display.
    let scale: CGFloat
    var snapping: EdgeSnapping
    private(set) var rect: CGRect?
    private(set) var phase = Phase.idle

    init(bounds: CGRect, scale: CGFloat, snapping: EdgeSnapping = EdgeSnapping()) {
        self.bounds = bounds
        self.scale = max(scale, 1)
        self.snapping = snapping
    }

    var isDragging: Bool {
        phase != .idle
    }

    var isDrawing: Bool {
        if case .drawing = phase {
            return true
        }
        return false
    }

    var isMoving: Bool {
        if case .moving = phase {
            return true
        }
        return false
    }

    /// The selection's size in pixels, as the W × H readout shows it.
    var pixelSize: CGSize? {
        guard let rect else { return nil }
        return CGSize(width: (rect.width * scale).rounded(), height: (rect.height * scale).rounded())
    }

    /// Starts a drag: on a handle it resizes, inside the selection it moves, anywhere else it draws a new one.
    mutating func begin(at point: CGPoint, handleTolerance: CGFloat = 6) {
        let point = CaptureGeometry.clamp(point, to: bounds)
        if let rect, let handle = handle(at: point, tolerance: handleTolerance) {
            phase = .resizing(handle, original: rect)
        } else if let rect, rect.contains(point) {
            phase = .moving(start: point, original: rect)
        } else {
            phase = .drawing(anchor: point, current: point)
        }
    }

    /// Follows the pointer. `movesAnchor` is Space held while drawing: the rectangle keeps its size and moves.
    /// `snaps` is false while ⌘ is held.
    mutating func drag(to pointer: CGPoint, movesAnchor: Bool = false, snaps: Bool = true) {
        let point = CaptureGeometry.clamp(pointer, to: bounds)
        switch phase {
        case .idle:
            return
        case let .drawing(anchor, current):
            if movesAnchor {
                moveDrawing(anchor: anchor, current: current, to: point)
            } else {
                phase = .drawing(anchor: anchor, current: point)
                updateDrawnRect(anchor: anchor, current: point, snaps: snaps)
            }
        case let .moving(start, original):
            var moved = CaptureGeometry.shiftInside(
                original.offsetBy(dx: point.x - start.x, dy: point.y - start.y),
                bounds: bounds
            )
            if snaps {
                let dx = snapping.offsetX(minX: moved.minX, maxX: moved.maxX)
                let dy = snapping.offsetY(minY: moved.minY, maxY: moved.maxY)
                moved = CaptureGeometry.shiftInside(moved.offsetBy(dx: dx, dy: dy), bounds: bounds)
            }
            rect = aligned(moved)
        case let .resizing(handle, original):
            let target = snaps ? snapped(point) : point
            rect = aligned(Self.resize(original, handle: handle, to: target).intersection(bounds))
        }
    }

    /// Ends the drag. Returns false when it was a click that drew nothing, so the caller can treat it as one.
    @discardableResult
    mutating func end() -> Bool {
        defer { phase = .idle }
        switch phase {
        case .idle:
            return false
        case let .drawing(anchor, current):
            guard Self.isDrag(from: anchor, to: current) else { return false }
            enforceMinimumSize()
            return true
        case .moving, .resizing:
            enforceMinimumSize()
            return true
        }
    }

    /// Replaces the selection, e.g. with the frame of the window that was clicked.
    mutating func select(_ newRect: CGRect) {
        phase = .idle
        let clipped = newRect.intersection(bounds)
        rect = clipped.isNull || clipped.isEmpty ? nil : aligned(clipped)
    }

    mutating func clear() {
        phase = .idle
        rect = nil
    }

    /// Moves the selection by whole device pixels (arrows: 1, with Shift: 10), keeping it on the display.
    mutating func nudge(dx: Int, dy: Int) {
        guard let rect else { return }
        let moved = rect.offsetBy(dx: CGFloat(dx) / scale, dy: CGFloat(dy) / scale)
        self.rect = aligned(CaptureGeometry.shiftInside(moved, bounds: bounds))
    }

    /// Grows or shrinks the selection by whole device pixels, keeping its top-left corner (Option-arrows).
    mutating func resize(dWidth: Int, dHeight: Int) {
        guard let rect else { return }
        let pixel = 1 / scale
        let width = min(max(rect.width + CGFloat(dWidth) / scale, pixel), bounds.maxX - rect.minX)
        let height = min(max(rect.height + CGFloat(dHeight) / scale, pixel), bounds.maxY - rect.minY)
        self.rect = aligned(CGRect(x: rect.minX, y: rect.minY, width: width, height: height))
    }

    /// The handle under `point`: corners first, then the edges.
    func handle(at point: CGPoint, tolerance: CGFloat) -> SelectionHandle? {
        guard let rect, rect.width > 0, rect.height > 0 else { return nil }
        for handle in SelectionHandle.allCases where handle.isCorner {
            let corner = handle.point(in: rect)
            if abs(point.x - corner.x) <= tolerance, abs(point.y - corner.y) <= tolerance {
                return handle
            }
        }
        let withinX = point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance
        let withinY = point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
        if withinY, abs(point.x - rect.minX) <= tolerance {
            return .left
        }
        if withinY, abs(point.x - rect.maxX) <= tolerance {
            return .right
        }
        if withinX, abs(point.y - rect.minY) <= tolerance {
            return .top
        }
        if withinX, abs(point.y - rect.maxY) <= tolerance {
            return .bottom
        }
        return nil
    }

    /// `original` with the edges that `handle` moves set to `point`; dragging past the opposite edge flips it.
    static func resize(_ original: CGRect, handle: SelectionHandle, to point: CGPoint) -> CGRect {
        let minX = handle.movesMinX ? point.x : original.minX
        let maxX = handle.movesMaxX ? point.x : original.maxX
        let minY = handle.movesMinY ? point.y : original.minY
        let maxY = handle.movesMaxY ? point.y : original.maxY
        return ScreenGeometry.rect(from: CGPoint(x: minX, y: minY), to: CGPoint(x: maxX, y: maxY))
    }

    static func isDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        abs(end.x - start.x) >= minimumDrag || abs(end.y - start.y) >= minimumDrag
    }

    private mutating func moveDrawing(anchor: CGPoint, current: CGPoint, to point: CGPoint) {
        let dx = point.x - current.x
        let dy = point.y - current.y
        var newAnchor = CGPoint(x: anchor.x + dx, y: anchor.y + dy)
        var newCurrent = point
        let moved = ScreenGeometry.rect(from: newAnchor, to: newCurrent)
        let inside = CaptureGeometry.shiftInside(moved, bounds: bounds)
        let correctionX = inside.minX - moved.minX
        let correctionY = inside.minY - moved.minY
        newAnchor = CGPoint(x: newAnchor.x + correctionX, y: newAnchor.y + correctionY)
        newCurrent = CGPoint(x: newCurrent.x + correctionX, y: newCurrent.y + correctionY)
        phase = .drawing(anchor: newAnchor, current: newCurrent)
        updateDrawnRect(anchor: newAnchor, current: newCurrent, snaps: false)
    }

    private mutating func updateDrawnRect(anchor: CGPoint, current: CGPoint, snaps: Bool) {
        guard Self.isDrag(from: anchor, to: current) else { return }
        let target = snaps ? snapped(current) : current
        rect = aligned(ScreenGeometry.rect(from: anchor, to: target).intersection(bounds))
    }

    private mutating func enforceMinimumSize() {
        guard let rect else { return }
        let pixel = 1 / scale
        guard rect.width < pixel || rect.height < pixel else { return }
        let grown = CGRect(x: rect.minX, y: rect.minY, width: max(rect.width, pixel), height: max(rect.height, pixel))
        self.rect = aligned(CaptureGeometry.shiftInside(grown, bounds: bounds))
    }

    private func snapped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: snapping.snapX(point.x), y: snapping.snapY(point.y))
    }

    private func aligned(_ rect: CGRect) -> CGRect {
        CaptureGeometry.align(rect, in: bounds, scale: scale)
    }
}
