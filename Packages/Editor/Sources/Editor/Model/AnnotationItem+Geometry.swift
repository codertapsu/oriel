import CoreGraphics

/// Geometry of an item in image space: what it covers, where its handles are, what a click hits, and how it
/// moves, resizes and takes a new style.
extension AnnotationItem {
    /// What the item covers when drawn, strokes and arrowheads included.
    nonisolated var bounds: CGRect {
        switch self {
        case let .arrow(arrow):
            let reach = max(arrow.width, arrow.headWidth) / 2
            return Geometry.rect(through: arrow.start, arrow.end).insetBy(dx: -reach, dy: -reach)
        case let .line(line):
            return Geometry.rect(through: line.start, line.end).insetBy(dx: -line.width / 2, dy: -line.width / 2)
        case let .rect(box), let .ellipse(box):
            return box.rect.standardized.insetBy(dx: -box.width / 2, dy: -box.width / 2)
        case let .freehand(path), let .highlighter(path):
            return path.pointBounds.insetBy(dx: -path.width / 2, dy: -path.width / 2)
        case let .text(text):
            return text.frame
        case let .counter(counter):
            return counter.circleRect.insetBy(dx: -counter.radius * 0.12, dy: -counter.radius * 0.12)
        case let .blur(region), let .pixelate(region), let .spotlight(region):
            return region.rect.standardized
        }
    }

    /// The rect the box handles sit on.
    nonisolated var frame: CGRect {
        switch self {
        case let .arrow(arrow): Geometry.rect(through: arrow.start, arrow.end)
        case let .line(line): Geometry.rect(through: line.start, line.end)
        case let .rect(box), let .ellipse(box): box.rect.standardized
        case let .freehand(path), let .highlighter(path): path.pointBounds
        case let .text(text): text.frame
        case let .counter(counter): counter.circleRect
        case let .blur(region), let .pixelate(region), let .spotlight(region): region.rect.standardized
        }
    }

    /// The handles a single selected item shows. Labels and step markers only move.
    nonisolated var handles: [SelectionHandle] {
        switch self {
        case .arrow, .line: [.start, .end]
        case .rect, .ellipse, .blur, .pixelate, .spotlight: SelectionHandle.boxHandles
        case .freehand, .highlighter: SelectionHandle.cornerHandles
        case .text, .counter: []
        }
    }

    nonisolated func position(of handle: SelectionHandle) -> CGPoint {
        switch (self, handle) {
        case let (.arrow(arrow), .start): arrow.start
        case let (.arrow(arrow), .end): arrow.end
        case let (.line(line), .start): line.start
        case let (.line(line), .end): line.end
        default: handle.point(in: frame)
        }
    }

    /// The handle within `tolerance` of `point`, if any.
    nonisolated func handle(at point: CGPoint, tolerance: CGFloat) -> SelectionHandle? {
        handles.first { handle in
            let position = position(of: handle)
            return abs(position.x - point.x) <= tolerance && abs(position.y - point.y) <= tolerance
        }
    }

    /// Whether `point` hits the item; `tolerance` is how far off (in points) still counts.
    nonisolated func hitTest(_ point: CGPoint, tolerance: CGFloat) -> HitPrecision? {
        switch self {
        case let .arrow(arrow): Self.hitTest(arrow, point, tolerance)
        case let .line(line):
            Geometry.distance(from: point, toSegmentFrom: line.start, to: line.end) <= line.width / 2 + tolerance ? .precise : nil
        case let .rect(box): Self.hitTestRect(box, point, tolerance)
        case let .ellipse(box): Self.hitTestEllipse(box, point, tolerance)
        case let .freehand(path), let .highlighter(path): Self.hitTest(path, point, tolerance)
        case let .text(text): text.frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point) ? .precise : nil
        case let .counter(counter):
            hypot(point.x - counter.center.x, point.y - counter.center.y) <= counter.radius + tolerance ? .precise : nil
        case let .blur(region), let .pixelate(region), let .spotlight(region):
            region.rect.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point) ? .precise : nil
        }
    }

    nonisolated func offsetBy(dx: CGFloat, dy: CGFloat) -> AnnotationItem {
        func moved(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + dx, y: point.y + dy)
        }
        switch self {
        case var .arrow(arrow):
            arrow.start = moved(arrow.start)
            arrow.end = moved(arrow.end)
            return .arrow(arrow)
        case var .line(line):
            line.start = moved(line.start)
            line.end = moved(line.end)
            return .line(line)
        case var .rect(box):
            box.rect = box.rect.offsetBy(dx: dx, dy: dy)
            return .rect(box)
        case var .ellipse(box):
            box.rect = box.rect.offsetBy(dx: dx, dy: dy)
            return .ellipse(box)
        case var .freehand(path):
            path.points = path.points.map(moved)
            return .freehand(path)
        case var .highlighter(path):
            path.points = path.points.map(moved)
            return .highlighter(path)
        case var .text(text):
            text.origin = moved(text.origin)
            return .text(text)
        case var .counter(counter):
            counter.center = moved(counter.center)
            return .counter(counter)
        case let .blur(region), let .pixelate(region), let .spotlight(region):
            return withRegionRect(region.rect.offsetBy(dx: dx, dy: dy))
        }
    }

    /// The item with `handle` dragged to `point`. `constrained` (Shift) snaps line ends to 45°.
    nonisolated func resized(moving handle: SelectionHandle, to point: CGPoint, constrained: Bool = false) -> AnnotationItem {
        switch self {
        case var .arrow(arrow):
            if handle == .start {
                arrow.start = constrained ? Geometry.snappedEnd(from: arrow.end, to: point) : point
            } else if handle == .end {
                arrow.end = constrained ? Geometry.snappedEnd(from: arrow.start, to: point) : point
            }
            return .arrow(arrow)
        case var .line(line):
            if handle == .start {
                line.start = constrained ? Geometry.snappedEnd(from: line.end, to: point) : point
            } else if handle == .end {
                line.end = constrained ? Geometry.snappedEnd(from: line.start, to: point) : point
            }
            return .line(line)
        case var .rect(box):
            box.rect = Geometry.resize(box.rect.standardized, moving: handle, to: point)
            return .rect(box)
        case var .ellipse(box):
            box.rect = Geometry.resize(box.rect.standardized, moving: handle, to: point)
            return .ellipse(box)
        case let .freehand(path):
            return .freehand(Self.scaled(path, moving: handle, to: point))
        case let .highlighter(path):
            return .highlighter(Self.scaled(path, moving: handle, to: point))
        case .text, .counter:
            return self
        case let .blur(region), let .pixelate(region), let .spotlight(region):
            return withRegionRect(Geometry.resize(region.rect.standardized, moving: handle, to: point))
        }
    }

    /// The item drawn in `color` at the toolbar's `width` setting (see `ToolStyle`); nil leaves that alone.
    nonisolated func styled(color: RGBAColor?, width: CGFloat?) -> AnnotationItem {
        switch self {
        case var .arrow(arrow):
            arrow.color = color ?? arrow.color
            arrow.width = width ?? arrow.width
            return .arrow(arrow)
        case var .line(line):
            line.color = color ?? line.color
            line.width = width ?? line.width
            return .line(line)
        case var .rect(box):
            box.color = color ?? box.color
            box.width = width ?? box.width
            return .rect(box)
        case var .ellipse(box):
            box.color = color ?? box.color
            box.width = width ?? box.width
            return .ellipse(box)
        case var .freehand(path):
            path.color = color ?? path.color
            path.width = width ?? path.width
            return .freehand(path)
        case var .highlighter(path):
            path.color = color ?? path.color
            path.width = width.map(ToolStyle.highlighterWidth) ?? path.width
            return .highlighter(path)
        default:
            return styledLabelOrEffect(color: color, width: width)
        }
    }

    // MARK: - Helpers

    private nonisolated func styledLabelOrEffect(color: RGBAColor?, width: CGFloat?) -> AnnotationItem {
        switch self {
        case var .text(text):
            text.color = color ?? text.color
            text.fontSize = width.map(ToolStyle.fontSize) ?? text.fontSize
            return .text(text)
        case var .counter(counter):
            counter.color = color ?? counter.color
            counter.radius = width.map(ToolStyle.counterRadius) ?? counter.radius
            return .counter(counter)
        case var .blur(region):
            region.amount = width.map(ToolStyle.effectAmount) ?? region.amount
            return .blur(region)
        case var .pixelate(region):
            region.amount = width.map(ToolStyle.effectAmount) ?? region.amount
            return .pixelate(region)
        default:
            return self
        }
    }

    /// A box or region item with a new rect; other kinds are returned unchanged.
    nonisolated func withRect(_ rect: CGRect) -> AnnotationItem {
        switch self {
        case var .rect(box):
            box.rect = rect
            return .rect(box)
        case var .ellipse(box):
            box.rect = rect
            return .ellipse(box)
        default:
            return withRegionRect(rect)
        }
    }

    private nonisolated func withRegionRect(_ rect: CGRect) -> AnnotationItem {
        switch self {
        case var .blur(region):
            region.rect = rect
            return .blur(region)
        case var .pixelate(region):
            region.rect = rect
            return .pixelate(region)
        case var .spotlight(region):
            region.rect = rect
            return .spotlight(region)
        default:
            return self
        }
    }

    private nonisolated static func hitTest(_ arrow: Arrow, _ point: CGPoint, _ tolerance: CGFloat) -> HitPrecision? {
        let distance = Geometry.distance(from: point, toSegmentFrom: arrow.start, to: arrow.end)
        if distance <= arrow.width / 2 + tolerance {
            return .precise
        }
        let nearHead = hypot(point.x - arrow.end.x, point.y - arrow.end.y) <= arrow.headLength + tolerance
        return nearHead && distance <= arrow.headWidth / 2 + tolerance ? .precise : nil
    }

    private nonisolated static func hitTestRect(_ box: Box, _ point: CGPoint, _ tolerance: CGFloat) -> HitPrecision? {
        let rect = box.rect.standardized
        let reach = box.width / 2 + tolerance
        guard rect.insetBy(dx: -reach, dy: -reach).contains(point) else { return nil }
        let inner = rect.insetBy(dx: reach, dy: reach)
        return !inner.isNull && inner.contains(point) ? .interior : .precise
    }

    private nonisolated static func hitTestEllipse(_ box: Box, _ point: CGPoint, _ tolerance: CGFloat) -> HitPrecision? {
        let outline = Geometry.ellipseOutlineDistance(from: point, in: box.rect.standardized)
        if outline.distance <= box.width / 2 + tolerance {
            return .precise
        }
        return outline.isInside ? .interior : nil
    }

    private nonisolated static func hitTest(_ path: FreehandPath, _ point: CGPoint, _ tolerance: CGFloat) -> HitPrecision? {
        let reach = path.width / 2 + tolerance
        guard let first = path.points.first else { return nil }
        guard path.points.count > 1 else {
            return hypot(point.x - first.x, point.y - first.y) <= reach ? .precise : nil
        }
        for index in path.points.indices.dropFirst() {
            let distance = Geometry.distance(from: point, toSegmentFrom: path.points[index - 1], to: path.points[index])
            if distance <= reach {
                return .precise
            }
        }
        return nil
    }

    private nonisolated static func scaled(_ path: FreehandPath, moving handle: SelectionHandle, to point: CGPoint) -> FreehandPath {
        let source = path.pointBounds
        guard !source.isNull else { return path }
        let target = Geometry.resize(source, moving: handle, to: point)
        var scaled = path
        scaled.points = path.points.map { Geometry.map($0, from: source, to: target) }
        return scaled
    }
}
