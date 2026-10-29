import CoreGraphics

/// Turns the session into what each display draws, and into the hint bar's keys.
nonisolated enum RulerSceneBuilder {
    /// An arm or a gap shorter than this, in points, has no number on it: the badge would cover the line.
    static let shortestLabelledLength: CGFloat = 28

    static func scene(for display: RulerDisplay, session: RulerSession) -> RulerScene {
        var scene = RulerScene()
        switch session.mode {
        case .measureArea: addArea(to: &scene, display: display, session: session)
        case .dimensions: addDimensions(to: &scene, display: display, session: session)
        case .guides: addGuides(to: &scene, display: display, session: session)
        }
        return scene
    }

    /// What the mode is for, then its keys, then the keys every mode has.
    static func hint(for session: RulerSession) -> (instruction: String, keys: [KeyHint]) {
        let unit = KeyHint(key: "U", label: session.unit.title)
        let common = [KeyHint(key: "⇥", label: "Mode"), unit, KeyHint(key: "⌘C", label: "Copy"), KeyHint(key: "⎋", label: "Close")]
        switch session.mode {
        case .measureArea:
            return (
                "Drag to measure",
                [KeyHint(key: "⇧", label: "Square"), KeyHint(key: "←→", label: "Nudge"), KeyHint(key: "⌥", label: "Resize")] + common
            )
        case .dimensions:
            let tolerance = KeyHint(key: "[ ]", label: "Tolerance \(session.tolerance)%")
            return ("Click to keep, drag around to fit", [tolerance] + common)
        case .guides:
            let other = session.guideOrientation == .vertical ? "Switch to horizontal" : "Switch to vertical"
            return ("Click to add", [KeyHint(key: "Space", label: other), KeyHint(key: "⌫", label: "Remove")] + common)
        }
    }

    // MARK: Measure Area

    private static func addArea(to scene: inout RulerScene, display: RulerDisplay, session: RulerSession) {
        let pointer = session.pointer.flatMap { display.contains($0) ? $0 : nil }
        let area = session.area?.display.id == display.id ? session.area : nil
        if let area, let rect = area.rect {
            scene.area = rect
            scene.showsHandles = !area.isDrawing
            let other = RulerFormat.otherSize(rect.size, unit: session.unit, scale: display.scale)
            let position = RulerFormat.position(rect.origin, on: display, unit: session.unit)
            scene.labels.append(RulerScene.Label(
                text: RulerFormat.size(rect.size, unit: session.unit, scale: display.scale),
                detail: "\(other)   \(position)",
                anchor: CGPoint(x: rect.midX, y: rect.maxY),
                placement: .below,
                style: .primary
            ))
        }
        // The crosshair helps aim a new area; once there is one, it would only be in the way.
        guard let pointer, area?.rect == nil || area?.isDrawing == true else { return }
        scene.crosshair = pointer
        if area?.isDrawing != true {
            scene.labels.append(RulerScene.Label(
                text: RulerFormat.position(display.snapped(pointer, to: session.unit), on: display, unit: session.unit),
                detail: nil,
                anchor: pointer,
                placement: .beside,
                style: .secondary
            ))
        }
    }

    // MARK: Dimensions

    private static func addDimensions(to scene: inout RulerScene, display: RulerDisplay, session: RulerSession) {
        if let pinned = session.pinned, pinned.display.id == display.id {
            scene.pinnedBox = pinned.rect
            scene.labels.append(RulerScene.Label(
                text: pinned.text(unit: session.unit),
                detail: nil,
                anchor: CGPoint(x: pinned.rect.midX, y: pinned.rect.maxY),
                placement: .below,
                style: .primary
            ))
        }
        if let fitting = session.fitting, fitting.display.id == display.id {
            scene.fitBox = fitting.rect
        }
        guard let pointer = session.pointer, display.contains(pointer) else { return }
        switch session.edgeStatus {
        case .notPermitted:
            scene.notice = .screenRecordingNeeded
            return
        case let .failed(reason):
            scene.notice = .readFailed(reason)
            return
        case .reading:
            scene.labels.append(RulerScene.Label(
                text: "Reading the screen…",
                detail: nil,
                anchor: pointer,
                placement: .beside,
                style: .secondary
            ))
            return
        case .ready:
            break
        }
        guard session.fitting == nil else { return }
        guard let measurement = session.dimensions else {
            scene.labels.append(RulerScene.Label(
                text: "This display could not be read",
                detail: nil,
                anchor: pointer,
                placement: .beside,
                style: .secondary
            ))
            return
        }
        let box = measurement.rect
        let point = CGPoint(x: min(max(pointer.x, box.minX), box.maxX), y: min(max(pointer.y, box.minY), box.maxY))
        scene.measuredBox = box
        scene.segments = [
            RulerScene.Segment(from: CGPoint(x: box.minX, y: point.y), to: CGPoint(x: box.maxX, y: point.y)),
            RulerScene.Segment(from: CGPoint(x: point.x, y: box.minY), to: CGPoint(x: point.x, y: box.maxY)),
        ]
        scene.labels.append(RulerScene.Label(
            text: measurement.text(unit: session.unit),
            detail: nil,
            anchor: point,
            placement: .beside,
            style: .primary
        ))
        let arms: [(length: CGFloat, middle: CGPoint)] = [
            (measurement.left, CGPoint(x: (box.minX + point.x) / 2, y: point.y)),
            (measurement.right, CGPoint(x: (point.x + box.maxX) / 2, y: point.y)),
            (measurement.up, CGPoint(x: point.x, y: (box.minY + point.y) / 2)),
            (measurement.down, CGPoint(x: point.x, y: (point.y + box.maxY) / 2)),
        ]
        for arm in arms where arm.length >= shortestLabelledLength {
            let text = RulerFormat.number(arm.length, unit: session.unit, scale: display.scale)
            scene.labels.append(RulerScene.Label(text: text, detail: nil, anchor: arm.middle, placement: .center, style: .secondary))
        }
    }

    // MARK: Guides

    private static func addGuides(to scene: inout RulerScene, display: RulerDisplay, session: RulerSession) {
        let pointer = session.pointer.flatMap { display.contains($0) ? $0 : nil }
        let hovered = pointer.flatMap { session.guides.guide(near: $0, on: display.id, tolerance: RulerSession.guideTolerance) }
        for orientation in [Guide.Orientation.vertical, .horizontal] {
            for guide in session.guides.guides(orientation, on: display.id) {
                let selected = guide.id == session.selectedGuide || guide.id == hovered?.id
                scene.guides.append(RulerScene.GuideLine(orientation: orientation, position: guide.position, isSelected: selected))
            }
        }
        var preview: RulerScene.GuideLine?
        if let pointer, hovered == nil, session.draggingGuide == nil {
            let snapped = display.snapped(pointer, to: session.unit)
            let position = session.guideOrientation == .vertical ? snapped.x : snapped.y
            let line = RulerScene.GuideLine(orientation: session.guideOrientation, position: position, isPreview: true)
            scene.guides.append(line)
            preview = line
        }
        // Distances along the pointer's row between the vertical lines, and down its column between the horizontal ones,
        // from the display's edges in.
        let across = pointer?.y ?? display.frame.midY
        let down = pointer?.x ?? display.frame.midX
        for orientation in [Guide.Orientation.vertical, .horizontal] {
            var stops = session.guides.guides(orientation, on: display.id).map(\.position)
            if let preview, preview.orientation == orientation {
                stops.append(preview.position)
            }
            guard !stops.isEmpty else { continue }
            let edges = orientation == .vertical ? [display.frame.minX, display.frame.maxX] : [display.frame.minY, display.frame.maxY]
            let sorted = Array(Set(stops + edges)).sorted()
            for (low, high) in zip(sorted, sorted.dropFirst()) where high > low {
                let segment = orientation == .vertical
                    ? RulerScene.Segment(from: CGPoint(x: low, y: across), to: CGPoint(x: high, y: across))
                    : RulerScene.Segment(from: CGPoint(x: down, y: low), to: CGPoint(x: down, y: high))
                scene.segments.append(segment)
                guard high - low >= shortestLabelledLength else { continue }
                let middle = CGPoint(x: (segment.from.x + segment.to.x) / 2, y: (segment.from.y + segment.to.y) / 2)
                let text = RulerFormat.number(high - low, unit: session.unit, scale: display.scale)
                scene.labels.append(RulerScene.Label(text: text, detail: nil, anchor: middle, placement: .center, style: .secondary))
            }
        }
    }
}
