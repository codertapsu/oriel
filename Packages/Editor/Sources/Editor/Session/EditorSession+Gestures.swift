import CoreGraphics
import Foundation
import OrielCore

/// Pointer input, in image space. A press starts a gesture, drags update it and the release turns it into
/// one undo step, however many drag events there were.
extension EditorSession {
    /// Starts a gesture at `point`. `tolerance` is how far a click may miss, in image points (the view passes a
    /// few screen points divided by the zoom). Shift constrains, Shift or ⌘ toggles selection.
    func beginGesture(at point: CGPoint, modifiers: KeyCombo.Modifiers = [], tolerance: CGFloat = 4, clickCount: Int = 1) {
        cancelGesture()
        endEditingText()
        gestureSnapshot = document
        gestureTolerance = max(tolerance, 0.01)
        switch tool {
        case .select: beginSelecting(at: point, modifiers: modifiers, clickCount: clickCount)
        case .crop: beginCropping(at: point)
        case .text: beginText(at: point)
        case .counter: beginCounter(at: point)
        default: beginDrawing(at: point)
        }
    }

    func continueGesture(to point: CGPoint, modifiers: KeyCombo.Modifiers = []) {
        guard let gesture else { return }
        let constrained = modifiers.contains(.shift)
        switch gesture {
        case let .creating(id, start):
            updateCreatedItem(id, from: start, to: point, constrained: constrained)
        case let .drawing(id):
            appendPoint(point, toStroke: id)
        case let .moving(originals, start):
            var dx = point.x - start.x, dy = point.y - start.y
            if constrained {
                if abs(dx) > abs(dy) {
                    dy = 0
                } else {
                    dx = 0
                }
            }
            var updated = document
            for item in originals.values {
                updated.replace(item.offsetBy(dx: dx, dy: dy))
            }
            preview(updated)
        case let .placingStep(id, tip):
            guard case var .counter(counter) = document.item(withID: id) else { return }
            counter.center = point
            counter.pointer = tip
            var updated = document
            updated.replace(.counter(counter))
            preview(updated)
        case let .resizing(original, handle):
            var updated = document
            updated.replace(original.resized(moving: handle, to: point, constrained: constrained))
            preview(updated)
        case let .marquee(start, base):
            let rect = Geometry.rect(through: start, point)
            marquee = rect
            selection = base.union(document.items.filter { $0.isSelectable && $0.bounds.intersects(rect) }.map(\.id))
            notify()
        case let .cropNew(start, _):
            cropDraft = clampedCrop(Geometry.rect(from: start, to: point, square: constrained))
            notify()
        case let .cropMove(original, start):
            cropDraft = movedCrop(original, dx: point.x - start.x, dy: point.y - start.y)
            notify()
        case let .cropResize(original, handle):
            cropDraft = clampedCrop(Geometry.resize(original, moving: handle, to: point))
            notify()
        }
    }

    func endGesture() {
        guard let gesture else { return }
        let snapshot = gestureSnapshot ?? document
        self.gesture = nil
        gestureSnapshot = nil
        switch gesture {
        case let .creating(id, _), let .drawing(id):
            let kind = document.item(withID: id)?.kind
            if let item = document.item(withID: id), isDegenerate(item) {
                var updated = document
                updated.remove([id])
                selection.remove(id)
                preview(updated)
            }
            finish(from: snapshot, actionName: kind?.actionName ?? "Draw")
        case let .moving(originals, _):
            let placedNew = originals.keys.contains { snapshot.item(withID: $0) == nil }
            if placedNew {
                pendingStepStart = nil
            }
            finish(from: snapshot, actionName: placedNew ? AnnotationKind.counter.actionName : "Move")
        case let .placingStep(id, tip):
            // A click, or a drag too short to say where the marker goes: it sits beside the point, towards the
            // middle of the image.
            if case var .counter(counter) = document.item(withID: id), !counter.showsPointer(farther: 1.5) {
                counter.center = StepGeometry.defaultCenter(pointingAt: tip, radius: counter.radius, in: document.visibleImageRect)
                var updated = document
                updated.replace(.counter(counter))
                preview(updated)
            }
            pendingStepStart = nil
            finish(from: snapshot, actionName: AnnotationKind.counter.actionName)
        case .resizing:
            finish(from: snapshot, actionName: "Resize")
        case .marquee:
            marquee = nil
            notify()
        case let .cropNew(_, previous):
            if let draft = cropDraft, draft.width < 4 || draft.height < 4 {
                cropDraft = previous
            }
            notify()
        case .cropMove, .cropResize:
            notify()
        }
    }

    /// Abandons the gesture and puts back what it changed.
    func cancelGesture() {
        guard let gesture else { return }
        let snapshot = gestureSnapshot
        self.gesture = nil
        gestureSnapshot = nil
        marquee = nil
        switch gesture {
        case let .cropNew(_, previous):
            cropDraft = previous
        case let .cropMove(original, _), let .cropResize(original, _):
            cropDraft = original
        default:
            if let snapshot {
                selection = selection.filter { snapshot.item(withID: $0) != nil }
                preview(snapshot)
            }
        }
        notify()
    }

    /// The item a click at `point` lands on, in visual order: vector annotations above image effects, then
    /// z-order; a precise hit anywhere beats the inside of an unfilled shape.
    func item(at point: CGPoint, tolerance: CGFloat) -> AnnotationItem? {
        let visualOrder = document.items.filter(\.isImageLayer) + document.items.filter { !$0.isImageLayer }
        var interiorHit: AnnotationItem?
        for item in visualOrder.reversed() {
            switch item.hitTest(point, tolerance: tolerance) {
            case .precise: return item
            case .interior: interiorHit = interiorHit ?? item
            case nil: continue
            }
        }
        return interiorHit
    }

    // MARK: - Starting gestures

    private func beginSelecting(at point: CGPoint, modifiers: KeyCombo.Modifiers, clickCount: Int) {
        if let resize = handleGesture(at: point) {
            gesture = resize
            return
        }
        guard let hit = item(at: point, tolerance: gestureTolerance) else {
            if !modifiers.contains(.shift), !modifiers.contains(.command) {
                selection = []
            }
            gesture = .marquee(start: point, base: selection)
            notify()
            return
        }
        if modifiers.contains(.shift) || modifiers.contains(.command) {
            if selection.contains(hit.id) {
                selection.remove(hit.id)
            } else {
                selection.insert(hit.id)
            }
            notify()
            return
        }
        if !selection.contains(hit.id) {
            selection = [hit.id]
            adoptStyle(of: hit)
        }
        if clickCount >= 2, case .text = hit {
            beginEditingText(hit.id)
            return
        }
        var originals: [UUID: AnnotationItem] = [:]
        for id in selection {
            originals[id] = document.item(withID: id)
        }
        gesture = .moving(originals: originals, start: point)
        notify()
    }

    /// Drawing tools: drag a handle of the selected item to adjust it, else draw a new item.
    private func beginDrawing(at point: CGPoint) {
        if let resize = handleGesture(at: point) {
            gesture = resize
            return
        }
        guard let kind = tool.drawsKind, let item = makeItem(kind, at: point) else { return }
        var updated = document
        updated.items.append(item)
        selection = [item.id]
        gesture = kind == .freehand || kind == .highlighter ? .drawing(id: item.id) : .creating(id: item.id, start: point)
        preview(updated)
    }

    /// Text tool: click a label to edit it, anywhere else to start a new one there.
    private func beginText(at point: CGPoint) {
        let snapshot = document
        if let hit = item(at: point, tolerance: gestureTolerance), case .text = hit {
            beginEditingText(hit.id, snapshot: snapshot)
            return
        }
        let fontSize = ToolStyle.fontSize(strokeWidth)
        let lineHeight = TextLayout.size(of: "", fontSize: fontSize).height
        let box = TextBox(origin: CGPoint(x: point.x, y: point.y - lineHeight / 2), text: "", color: color, fontSize: fontSize)
        var updated = document
        updated.items.append(.text(box))
        preview(updated)
        beginEditingText(box.id, snapshot: snapshot)
    }

    /// Step tool: drag the selected marker's pointer tip to aim it, drag an existing marker to move it, click anywhere
    /// else to place the next number. With the pointer style, the press marks what the step points at and the drag
    /// carries the marker to where it should sit.
    private func beginCounter(at point: CGPoint) {
        if let resize = handleGesture(at: point) {
            gesture = resize
            return
        }
        if let hit = item(at: point, tolerance: gestureTolerance), case .counter = hit {
            selection = [hit.id]
            adoptStyle(of: hit)
            gesture = .moving(originals: [hit.id: hit], start: point)
            notify()
            return
        }
        let (sequence, number) = nextStepPlacement
        let counter = Counter(
            center: point,
            number: number,
            color: color,
            radius: ToolStyle.counterRadius(strokeWidth),
            shape: stepStyle.shape,
            label: stepStyle.label,
            pointer: stepStyle.pointer ? point : nil,
            sequence: sequence
        )
        var updated = document
        updated.items.append(.counter(counter))
        selection = [counter.id]
        gesture = stepStyle.pointer
            ? .placingStep(id: counter.id, tip: point)
            : .moving(originals: [counter.id: .counter(counter)], start: point)
        preview(updated)
    }

    /// The sequence and number the next step marker gets: the newest sequence's next number, or a new sequence at
    /// the start number Restart Numbering asked for.
    var nextStepPlacement: (sequence: Int, number: Int) {
        let latest = document.latestStepSequence
        guard let start = pendingStepStart else {
            return (latest, document.nextStepNumber(inSequence: latest))
        }
        let hasSteps = document.items.contains { $0.kind == .counter }
        return (hasSteps ? latest + 1 : latest, start)
    }

    /// Crop tool: drag a handle to resize, inside a crop to move it, anywhere else (or anywhere, while nothing is
    /// cropped yet) to draw a new crop.
    private func beginCropping(at point: CGPoint) {
        let draft = cropDraft ?? document.visibleImageRect
        let tolerance = gestureTolerance
        if let handle = SelectionHandle.boxHandles.first(where: { handle in
            let position = handle.point(in: draft)
            return abs(position.x - point.x) <= tolerance && abs(position.y - point.y) <= tolerance
        }) {
            gesture = .cropResize(original: draft, handle: handle)
        } else if draft.contains(point), draft != document.base.bounds {
            gesture = .cropMove(original: draft, start: point)
        } else {
            gesture = .cropNew(start: point, previous: draft)
        }
    }

    // MARK: - Helpers

    private func handleGesture(at point: CGPoint) -> ActiveGesture? {
        guard selection.count == 1, let id = selection.first, let item = document.item(withID: id),
              let handle = item.handle(at: point, tolerance: gestureTolerance)
        else { return nil }
        return .resizing(original: item, handle: handle)
    }

    private func makeItem(_ kind: AnnotationKind, at point: CGPoint) -> AnnotationItem? {
        let rect = CGRect(origin: point, size: .zero)
        let amount = ToolStyle.effectAmount(strokeWidth)
        return switch kind {
        case .arrow: .arrow(Arrow(start: point, end: point, color: color, width: strokeWidth))
        case .line: .line(Line(start: point, end: point, color: color, width: strokeWidth))
        case .rect: .rect(Box(rect: rect, color: color, width: strokeWidth))
        case .ellipse: .ellipse(Box(rect: rect, color: color, width: strokeWidth))
        case .freehand: .freehand(FreehandPath(points: [point], color: color, width: strokeWidth))
        case .highlighter: .highlighter(FreehandPath(points: [point], color: color, width: ToolStyle.highlighterWidth(strokeWidth)))
        case .blur: .blur(Region(rect: rect, amount: amount))
        case .pixelate: .pixelate(Region(rect: rect, amount: amount))
        case .spotlight: .spotlight(Region(rect: rect, amount: 0))
        case .text, .counter, .image, .patch, .bar: nil
        }
    }

    private func updateCreatedItem(_ id: UUID, from start: CGPoint, to point: CGPoint, constrained: Bool) {
        guard let item = document.item(withID: id) else { return }
        let end = constrained ? Geometry.snappedEnd(from: start, to: point) : point
        let updatedItem: AnnotationItem
        switch item {
        case var .arrow(arrow):
            arrow.end = end
            updatedItem = .arrow(arrow)
        case var .line(line):
            line.end = end
            updatedItem = .line(line)
        default:
            updatedItem = item.withRect(Geometry.rect(from: start, to: point, square: constrained))
        }
        var updated = document
        updated.replace(updatedItem)
        preview(updated)
    }

    private func appendPoint(_ point: CGPoint, toStroke id: UUID) {
        let minimumStep = gestureTolerance / 4
        var updated = document
        switch document.item(withID: id) {
        case var .freehand(path):
            guard Self.isFarEnough(point, from: path.points.last, minimum: minimumStep) else { return }
            path.points.append(point)
            updated.replace(.freehand(path))
        case var .highlighter(path):
            guard Self.isFarEnough(point, from: path.points.last, minimum: minimumStep) else { return }
            path.points.append(point)
            updated.replace(.highlighter(path))
        default:
            return
        }
        preview(updated)
    }

    private static func isFarEnough(_ point: CGPoint, from last: CGPoint?, minimum: CGFloat) -> Bool {
        guard let last else { return true }
        return hypot(point.x - last.x, point.y - last.y) >= minimum
    }

    /// A click without a real drag leaves nothing behind (a pen dot is kept: it is what a click with a pen means).
    private func isDegenerate(_ item: AnnotationItem) -> Bool {
        let minimum = max(2, gestureTolerance * 0.75)
        switch item {
        case let .arrow(arrow): return hypot(arrow.end.x - arrow.start.x, arrow.end.y - arrow.start.y) < minimum
        case let .line(line): return hypot(line.end.x - line.start.x, line.end.y - line.start.y) < minimum
        case .rect, .ellipse, .blur, .pixelate, .spotlight: return item.frame.width < minimum || item.frame.height < minimum
        case .freehand, .highlighter, .text, .counter, .image, .patch, .bar: return false
        }
    }

    /// The crop rect kept inside the image, at least a few points wide.
    func clampedCrop(_ rect: CGRect) -> CGRect {
        let clipped = rect.standardized.intersection(document.base.bounds)
        return clipped.isNull ? CGRect(origin: rect.origin, size: .zero) : clipped
    }

    private func movedCrop(_ rect: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
        let bounds = document.base.bounds
        let x = min(max(rect.minX + dx, bounds.minX), bounds.maxX - rect.width)
        let y = min(max(rect.minY + dy, bounds.minY), bounds.maxY - rect.height)
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }
}
