import CoreGraphics

/// The keys: Tab and 1–3 switch mode, U switches points and pixels, ⌘C copies, Return copies and closes, Esc closes,
/// `[` and `]` change the edge tolerance, Space turns the next guide the other way, ⌫ removes what is selected, and the
/// arrows nudge (⌥ resizes) the area, move the selected guide, or move the point Dimensions measures from.
nonisolated extension RulerSession {
    mutating func handle(_ key: RulerKey) -> RulerEffect? {
        switch key {
        case .nextMode:
            setMode(mode.next)
        case .previousMode:
            setMode(mode.previous)
        case let .mode(mode):
            setMode(mode)
        case .toggleUnit:
            unit = unit.toggled
        case .copy:
            return measurementText.map(RulerEffect.copy) ?? .beep
        case .confirm:
            if mode == .dimensions, edgeStatus == .notPermitted {
                return .requestScreenRecording
            }
            return measurementText.map(RulerEffect.copyAndClose) ?? .beep
        case .exit:
            return .close
        case let .arrow(dx, dy, resizes):
            return arrow(dx: dx, dy: dy, resizes: resizes)
        case let .tolerance(delta):
            let range = RulerSettings.toleranceRange
            let changed = min(max(tolerance + delta, range.lowerBound), range.upperBound)
            guard changed != tolerance else { return .beep }
            tolerance = changed
            return .toleranceChanged(changed)
        case .flipGuide:
            guard mode == .guides else { return nil }
            guideOrientation = guideOrientation.flipped
        case let .guideOrientation(orientation):
            guard mode == .guides else { return nil }
            guideOrientation = orientation
        case .delete:
            return delete()
        case .deleteAll:
            guard mode == .guides, !guides.guides.isEmpty else { return .beep }
            guides.removeAll()
            selectedGuide = nil
        }
        return nil
    }

    private mutating func arrow(dx: Int, dy: Int, resizes: Bool) -> RulerEffect? {
        switch mode {
        case .measureArea:
            guard var editor = area, editor.rect != nil else { return .beep }
            if resizes {
                editor.resize(dWidth: dx, dHeight: dy, unit: unit)
            } else {
                editor.nudge(dx: dx, dy: dy, unit: unit)
            }
            area = editor
        case .dimensions:
            // The pointer itself stays; the point measured from moves, for measuring to the exact pixel.
            guard let pointer, let display = display(at: pointer) else { return .beep }
            let step = unit.step(scale: display.scale)
            let moved = CGPoint(x: pointer.x + CGFloat(dx) * step, y: pointer.y + CGFloat(dy) * step)
            self.pointer = CGPoint(
                x: min(max(moved.x, display.frame.minX), display.frame.maxX - step),
                y: min(max(moved.y, display.frame.minY), display.frame.maxY - step)
            )
        case .guides:
            guard let id = selectedGuide, let guide = guides.guide(id), let display = display(guide.displayID) else { return .beep }
            let delta = guide.orientation == .vertical ? dx : dy
            guard delta != 0 else { return nil }
            guides.move(id, to: guide.position + CGFloat(delta) * unit.step(scale: display.scale), on: display)
        }
        return nil
    }

    private mutating func delete() -> RulerEffect? {
        switch mode {
        case .measureArea:
            guard area?.rect != nil else { return .beep }
            area?.clear()
        case .dimensions:
            guard pinned != nil else { return .beep }
            pinned = nil
        case .guides:
            guard let id = selectedGuide else { return .beep }
            guides.remove(id)
            selectedGuide = nil
        }
        return nil
    }
}
