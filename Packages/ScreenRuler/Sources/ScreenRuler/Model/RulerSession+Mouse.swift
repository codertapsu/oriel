import CoreGraphics
import Foundation

/// The pointer. Measure Area draws, moves and resizes the area (Shift for a square, ⌘ to stop snapping to edges);
/// Dimensions keeps the box under the pointer on a click, or fits a drawn box to its content; Guides adds a guide on a
/// click, drags guides, and removes one with a right click.
nonisolated extension RulerSession {
    mutating func pointerMoved(to point: CGPoint) {
        pointer = point
    }

    mutating func mouseDown(at point: CGPoint, clickCount: Int) -> RulerEffect? {
        pointer = point
        guard let display = display(at: point) else { return nil }
        switch mode {
        case .measureArea:
            if clickCount >= 2, area?.display.id == display.id, let rect = area?.rect, rect.contains(point) {
                return measurementText.map(RulerEffect.copyAndClose)
            }
            var editor = area?.display.id == display.id ? area ?? AreaSelection(display: display) : AreaSelection(display: display)
            editor.begin(at: point, unit: unit, handleTolerance: Self.handleTolerance)
            area = editor
        case .dimensions:
            fitting = FitDrag(display: display, start: point, end: point)
        case .guides:
            if let guide = guides.guide(near: point, on: display.id, tolerance: Self.guideTolerance) {
                selectedGuide = guide.id
            } else {
                let snapped = display.snapped(point, to: unit)
                selectedGuide = guides.add(guideOrientation, at: guideOrientation == .vertical ? snapped.x : snapped.y, on: display)
            }
            draggingGuide = selectedGuide
        }
        return nil
    }

    mutating func mouseDragged(to point: CGPoint, square: Bool, snaps: Bool) {
        pointer = point
        switch mode {
        case .measureArea:
            guard var editor = area else { return }
            let display = editor.display
            let snap: ((CGPoint) -> CGPoint)? = snaps && hasEdges(on: display.id) ? { [self] in snapToEdges($0, on: display) } : nil
            editor.drag(to: point, unit: unit, square: square, snap: snap)
            area = editor
        case .dimensions:
            guard let drag = fitting else { return }
            fitting?.end = drag.display.clamped(point)
        case .guides:
            guard let id = draggingGuide, let guide = guides.guide(id), let display = display(guide.displayID) else { return }
            let snapped = display.snapped(point, to: unit)
            guides.move(id, to: guide.orientation == .vertical ? snapped.x : snapped.y, on: display)
        }
    }

    mutating func mouseUp(at point: CGPoint) -> RulerEffect? {
        pointer = point
        switch mode {
        case .measureArea:
            guard var editor = area else { return nil }
            // A click that drew nothing clears the area.
            if !editor.end() {
                editor.clear()
            }
            area = editor
        case .dimensions:
            guard let drag = fitting else { return nil }
            fitting = nil
            let moved = hypot(drag.end.x - drag.start.x, drag.end.y - drag.start.y)
            guard moved >= AreaSelection.minimumDrag else {
                // A click keeps the box under the pointer, or lets a kept one go when it is clicked again.
                let live = dimensions
                guard isProUnlocked || live == nil else { return .needsPro(.keptMeasurements) }
                pinned = live == nil || pinned?.box == live?.box ? nil : live
                return live == nil && edgeStatus != .ready ? .beep : nil
            }
            guard hasEdges(on: drag.display.id), !drag.pixelRect.isEmpty else { return .beep }
            return .fit(drag.pixelRect, displayID: drag.display.id, tolerance: channelTolerance)
        case .guides:
            draggingGuide = nil
        }
        return nil
    }

    /// A right click removes the guide under the pointer.
    mutating func rightMouseDown(at point: CGPoint) -> RulerEffect? {
        pointer = point
        guard mode == .guides, let display = display(at: point),
              let guide = guides.guide(near: point, on: display.id, tolerance: Self.guideTolerance)
        else { return nil }
        guides.remove(guide.id)
        if selectedGuide == guide.id {
            selectedGuide = nil
        }
        return nil
    }
}
