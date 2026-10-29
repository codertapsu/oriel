import CoreGraphics
import Foundation

/// One open ruler: its mode, unit and edge tolerance, what has been measured, and the guides, as the pointer and the
/// keys change them. Pure, so the whole interaction is tested; the overlay turns events into calls, draws the result
/// and does what a returned `RulerEffect` asks. All positions are global CoreGraphics points.
///
/// The state is readable inside the package, and only the session's own methods (here and in its Mouse and Keys
/// extensions) change it.
nonisolated struct RulerSession: Sendable {
    /// How close, in points, the pointer must be to a handle or a guide to grab it.
    static let handleTolerance: CGFloat = 6
    static let guideTolerance: CGFloat = 4
    /// How far, in points, a dragged edge looks for an edge on the screen to snap to.
    static let snapDistance: CGFloat = 5

    let displays: [RulerDisplay]
    var mode: RulerMode
    var unit: RulerUnit
    /// Percent of a channel's range (`RulerSettings.toleranceRange`).
    var tolerance: Int
    var edgeStatus: EdgeStatus
    var pointer: CGPoint?
    var area: AreaSelection?
    /// The box kept in Dimensions by a click, or fitted to the content of a box drawn there.
    var pinned: DimensionsMeasurement?
    var fitting: FitDrag?
    var guides = GuideSet()
    var selectedGuide: UUID?
    var draggingGuide: UUID?
    var guideOrientation = Guide.Orientation.vertical
    private var edgeMaps: [CGDirectDisplayID: EdgeMap] = [:]

    init(displays: [RulerDisplay], mode: RulerMode, unit: RulerUnit, tolerance: Int, edgeStatus: EdgeStatus) {
        self.displays = displays
        self.mode = mode
        self.unit = unit
        self.tolerance = min(max(tolerance, RulerSettings.toleranceRange.lowerBound), RulerSettings.toleranceRange.upperBound)
        self.edgeStatus = edgeStatus
    }

    var channelTolerance: Int {
        RulerSettings.channelTolerance(percent: tolerance)
    }

    func display(at point: CGPoint) -> RulerDisplay? {
        RulerDisplay.display(at: point, among: displays)
    }

    func display(_ id: CGDirectDisplayID) -> RulerDisplay? {
        displays.first { $0.id == id }
    }

    func hasEdges(on displayID: CGDirectDisplayID) -> Bool {
        edgeMaps[displayID] != nil
    }

    func edgeMap(for displayID: CGDirectDisplayID) -> EdgeMap? {
        edgeMaps[displayID]
    }

    /// Dimensions at the pointer, where edges can be read.
    var dimensions: DimensionsMeasurement? {
        guard mode == .dimensions, let pointer, let display = display(at: pointer), let map = edgeMaps[display.id] else { return nil }
        return DimensionsMeasurement(at: pointer, on: display, in: map, tolerance: channelTolerance)
    }

    /// What ⌘C copies in the current mode, when there is something measured.
    var measurementText: String? {
        switch mode {
        case .measureArea:
            guard let area, let rect = area.rect else { return nil }
            return RulerFormat.size(rect.size, unit: unit, scale: area.display.scale)
        case .dimensions:
            return (pinned ?? dimensions)?.text(unit: unit)
        case .guides:
            return guideGapText
        }
    }

    /// The space between the guides on either side of the pointer: `120 pt`, or `120 × 48 pt` with guides both ways.
    var guideGapText: String? {
        guard let pointer, let display = display(at: pointer) else { return nil }
        let hasVertical = !guides.guides(.vertical, on: display.id).isEmpty
        let hasHorizontal = !guides.guides(.horizontal, on: display.id).isEmpty
        let width = guides.bounds(around: pointer.x, .vertical, on: display)
        let height = guides.bounds(around: pointer.y, .horizontal, on: display)
        let size = CGSize(width: width.upperBound - width.lowerBound, height: height.upperBound - height.lowerBound)
        switch (hasVertical, hasHorizontal) {
        case (true, true): return RulerFormat.size(size, unit: unit, scale: display.scale)
        case (true, false): return RulerFormat.length(size.width, unit: unit, scale: display.scale)
        case (false, true): return RulerFormat.length(size.height, unit: unit, scale: display.scale)
        case (false, false): return nil
        }
    }

    /// The pointer shape for where the pointer is now.
    var cursor: RulerCursor {
        guard let pointer else { return .crosshair }
        switch mode {
        case .measureArea:
            guard let area else { return .crosshair }
            switch area.phase {
            case .moving: return .moving
            case let .resizing(handle, _): return .resize(handle)
            case .drawing: return .crosshair
            case .idle:
                guard area.display.contains(pointer) else { return .crosshair }
                if let handle = area.handle(at: pointer, tolerance: Self.handleTolerance) {
                    return .resize(handle)
                }
                return area.rect?.contains(pointer) == true ? .move : .crosshair
            }
        case .dimensions:
            return .crosshair
        case .guides:
            if let id = draggingGuide, let guide = guides.guide(id) {
                return .guide(guide.orientation)
            }
            guard let display = display(at: pointer),
                  let guide = guides.guide(near: pointer, on: display.id, tolerance: Self.guideTolerance)
            else { return .crosshair }
            return .guide(guide.orientation)
        }
    }

    // MARK: Edges

    mutating func setEdgeStatus(_ status: EdgeStatus) {
        edgeStatus = status
    }

    mutating func setEdgeMap(_ map: EdgeMap, for displayID: CGDirectDisplayID) {
        edgeMaps[displayID] = map
    }

    /// The result of a fit: the box shrunk to its content, kept on screen; nil leaves the drawn box out.
    mutating func pin(_ box: PixelRect?, on displayID: CGDirectDisplayID) {
        guard let box, let display = display(displayID) else { return }
        let center = CGPoint(x: CGFloat(box.minX + box.maxX) / 2, y: CGFloat(box.minY + box.maxY) / 2)
        pinned = DimensionsMeasurement(display: display, box: box, pointer: center)
    }

    // MARK: Modes

    mutating func setMode(_ mode: RulerMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        fitting = nil
        draggingGuide = nil
        if var area, area.isDragging {
            _ = area.end()
            self.area = area
        }
    }

    // MARK: Snapping

    /// Moves a point onto the nearest edge found on the screen, within `snapDistance`, along its row and its column.
    func snapToEdges(_ point: CGPoint, on display: RulerDisplay) -> CGPoint {
        guard let map = edgeMaps[display.id] else { return point }
        let radius = max(1, Int((Self.snapDistance * display.scale).rounded()))
        let pixel = display.pixel(at: point)
        let coordinate = display.pixelCoordinate(point)
        let tolerance = channelTolerance
        var snapped = point
        let column = map.nearestColumnEdge(row: pixel.y, near: Int(coordinate.x.rounded()), within: radius, tolerance: tolerance)
        if let column {
            snapped.x = display.globalX(column: column)
        }
        let row = map.nearestRowEdge(column: pixel.x, near: Int(coordinate.y.rounded()), within: radius, tolerance: tolerance)
        if let row {
            snapped.y = display.globalY(row: row)
        }
        return snapped
    }
}
