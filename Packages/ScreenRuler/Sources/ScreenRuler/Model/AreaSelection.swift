import CoreGraphics
import OrielCore

/// The measured area on one display, as the mouse and keyboard edit it. Pure, so the precision rules are tested: the
/// area stays on its display, its edges sit on the grid of the unit in use (whole points, or whole pixels), Shift makes
/// it square, the handles resize it, a drag inside moves it, and the arrows nudge or (with ⌥) resize it by one unit.
nonisolated struct AreaSelection: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case idle
        /// Drawing a new rectangle from `anchor`.
        case drawing(anchor: CGPoint)
        /// Moving the whole area: the drag began at `start`, when the area was `original`.
        case moving(start: CGPoint, original: CGRect)
        case resizing(RulerHandle, original: CGRect)
    }

    /// The shortest drag, in points, that counts as one; anything shorter is a click.
    static let minimumDrag: CGFloat = 2

    let display: RulerDisplay
    private(set) var rect: CGRect?
    private(set) var phase = Phase.idle
    private var pressedAt: CGPoint?
    private var hasDragged = false

    init(display: RulerDisplay, rect: CGRect? = nil) {
        self.display = display
        self.rect = rect.map { $0.intersection(display.frame) }
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

    /// Starts a drag: on a handle it resizes, inside the area it moves, anywhere else it draws a new one.
    mutating func begin(at point: CGPoint, unit: RulerUnit, handleTolerance: CGFloat) {
        pressedAt = point
        hasDragged = false
        if let rect, let handle = handle(at: point, tolerance: handleTolerance) {
            phase = .resizing(handle, original: rect)
        } else if let rect, rect.contains(point) {
            phase = .moving(start: point, original: rect)
        } else {
            phase = .drawing(anchor: display.snapped(point, to: unit))
        }
    }

    /// Follows the pointer. `square` (Shift) keeps width and height equal; `snap`, when given, moves the dragged edges
    /// onto edges found on the screen, and is not used for a square.
    mutating func drag(to point: CGPoint, unit: RulerUnit, square: Bool, snap: ((CGPoint) -> CGPoint)? = nil) {
        if !hasDragged, let pressedAt, hypot(point.x - pressedAt.x, point.y - pressedAt.y) < Self.minimumDrag {
            return
        }
        hasDragged = true
        switch phase {
        case .idle:
            return
        case let .drawing(anchor):
            let target = target(point, unit: unit, snap: square ? nil : snap)
            rect = square ? squared(from: anchor, to: target, unit: unit) : ScreenGeometry.rect(from: anchor, to: target)
        case let .moving(start, original):
            let step = unit.step(scale: display.scale)
            let offset = CGPoint(x: ((point.x - start.x) / step).rounded() * step, y: ((point.y - start.y) / step).rounded() * step)
            rect = kept(original.offsetBy(dx: offset.x, dy: offset.y))
        case let .resizing(handle, original):
            let target = target(point, unit: unit, snap: square ? nil : snap)
            rect = resized(original, handle: handle, to: target, unit: unit, square: square)
        }
    }

    /// Ends the drag. Returns false when it was a click that drew nothing, so the caller can treat it as one.
    mutating func end() -> Bool {
        defer {
            phase = .idle
            pressedAt = nil
        }
        if case .drawing = phase, !hasDragged {
            return false
        }
        if let rect, rect.width <= 0 || rect.height <= 0 {
            self.rect = nil
        }
        return rect != nil
    }

    /// Moves the area by whole units, staying on the display.
    mutating func nudge(dx: Int, dy: Int, unit: RulerUnit) {
        guard let rect else { return }
        let step = unit.step(scale: display.scale)
        self.rect = kept(rect.offsetBy(dx: CGFloat(dx) * step, dy: CGFloat(dy) * step))
    }

    /// Grows or shrinks the area from its top-left corner by whole units; it never gets smaller than one unit.
    mutating func resize(dWidth: Int, dHeight: Int, unit: RulerUnit) {
        guard let rect else { return }
        let step = unit.step(scale: display.scale)
        let width = min(max(step, rect.width + CGFloat(dWidth) * step), display.frame.maxX - rect.minX)
        let height = min(max(step, rect.height + CGFloat(dHeight) * step), display.frame.maxY - rect.minY)
        self.rect = CGRect(origin: rect.origin, size: CGSize(width: width, height: height))
    }

    /// Shows `rect` as the area, as when a measured box is turned into one.
    mutating func select(_ rect: CGRect) {
        let clipped = rect.intersection(display.frame)
        self.rect = clipped.isNull || clipped.isEmpty ? nil : clipped
        phase = .idle
    }

    mutating func clear() {
        rect = nil
        phase = .idle
    }

    /// The handle at `point`: a corner within `tolerance`, else an edge along its length.
    func handle(at point: CGPoint, tolerance: CGFloat) -> RulerHandle? {
        guard let rect else { return nil }
        let corners: [RulerHandle] = [.topLeft, .topRight, .bottomRight, .bottomLeft]
        let isNear = { (handle: RulerHandle) in
            let spot = handle.point(on: rect)
            return hypot(point.x - spot.x, point.y - spot.y) <= tolerance
        }
        if let corner = corners.first(where: isNear) {
            return corner
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

    // MARK: Geometry

    private func target(_ point: CGPoint, unit: RulerUnit, snap: ((CGPoint) -> CGPoint)?) -> CGPoint {
        let gridded = display.snapped(point, to: unit)
        return snap.map { display.clamped($0(gridded)) } ?? gridded
    }

    /// The largest square from `anchor` towards `target` that fits on the display, in whole units.
    private func squared(from anchor: CGPoint, to target: CGPoint, unit: RulerUnit) -> CGRect {
        let step = unit.step(scale: display.scale)
        let dx = target.x - anchor.x
        let dy = target.y - anchor.y
        let signX: CGFloat = dx < 0 ? -1 : 1
        let signY: CGFloat = dy < 0 ? -1 : 1
        let roomX = signX > 0 ? display.frame.maxX - anchor.x : anchor.x - display.frame.minX
        let roomY = signY > 0 ? display.frame.maxY - anchor.y : anchor.y - display.frame.minY
        let side = (min(max(abs(dx), abs(dy)), roomX, roomY) / step).rounded(.down) * step
        return ScreenGeometry.rect(from: anchor, to: CGPoint(x: anchor.x + signX * side, y: anchor.y + signY * side))
    }

    private func resized(_ original: CGRect, handle: RulerHandle, to target: CGPoint, unit: RulerUnit, square: Bool) -> CGRect {
        let step = unit.step(scale: display.scale)
        var minX = original.minX
        var maxX = original.maxX
        var minY = original.minY
        var maxY = original.maxY
        if handle.movesLeft {
            minX = min(target.x, maxX - step)
        }
        if handle.movesRight {
            maxX = max(target.x, minX + step)
        }
        if handle.movesTop {
            minY = min(target.y, maxY - step)
        }
        if handle.movesBottom {
            maxY = max(target.y, minY + step)
        }
        guard square, handle.isCorner else {
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).intersection(display.frame)
        }
        // The corner opposite the handle stays put.
        let anchor = CGPoint(x: handle.movesLeft ? maxX : minX, y: handle.movesTop ? maxY : minY)
        let side = max(maxX - minX, maxY - minY)
        let corner = CGPoint(x: anchor.x + (handle.movesLeft ? -side : side), y: anchor.y + (handle.movesTop ? -side : side))
        return squared(from: anchor, to: corner, unit: unit)
    }

    /// `rect` moved, not shrunk, back onto the display.
    private func kept(_ rect: CGRect) -> CGRect {
        let frame = display.frame
        let x = min(max(rect.minX, frame.minX), frame.maxX - rect.width)
        let y = min(max(rect.minY, frame.minY), frame.maxY - rect.height)
        return CGRect(x: x, y: y, width: min(rect.width, frame.width), height: min(rect.height, frame.height))
    }
}
