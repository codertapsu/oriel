import AppKit

/// The video editor's timeline (PLAN §17): a ruler, the filmstrip with the trim handles, the zoom lane and the
/// chapter lane, with the playhead across them.
///
/// Click or drag in the ruler or the filmstrip to move the playhead; drag the yellow handles to trim. In the zoom
/// lane, drag a zoom to move it, drag its ends to resize it, and double-click to add one. In the chapter lane,
/// click a marker to go to it, drag it to move it and double-click it to rename it. Scroll sideways to move
/// along a zoomed timeline; pinch, or scroll with ⌘, to zoom it.
///
/// The playhead is a layer of its own, so playback moves it without redrawing the rest.
final class TimelineView: NSView {
    /// Space on the left for the lanes' icons.
    static let gutter: CGFloat = 36
    static let trailingInset: CGFloat = 16
    static let rulerHeight: CGFloat = 22
    static let stripTop: CGFloat = 26
    static let stripHeight: CGFloat = 54
    static let zoomTop: CGFloat = 88
    static let laneHeight: CGFloat = 24
    static let chapterTop: CGFloat = 118
    static let preferredHeight: CGFloat = 150
    static let handleWidth: CGFloat = 11

    /// Asked to show the frame at a time; `scrubbing` is true while the mouse is down.
    var onSeek: ((_ time: Double, _ scrubbing: Bool) -> Void)?
    /// Asked to rename a chapter, after a double-click on its marker.
    var onRenameChapter: ((UUID) -> Void)?
    /// Called when the zoom of the timeline changes, for the zoom slider.
    var onMappingChange: (() -> Void)?

    let session: VideoEditorSession
    let thumbnails: ThumbnailCache
    private(set) var mapping: TimelineMapping
    /// The playhead's time.
    var playhead: Double = 0 {
        didSet { movePlayhead() }
    }

    private let playheadLayer = CALayer()
    private var drag: Drag?

    /// What a mouse drag is doing.
    private enum Drag {
        case scrub
        case trimStart(VideoEdit)
        case trimEnd(VideoEdit)
        case moveZoom(UUID, grab: Double, snapshot: VideoEdit)
        case resizeZoomStart(UUID, snapshot: VideoEdit)
        case resizeZoomEnd(UUID, snapshot: VideoEdit)
        case moveChapter(UUID, snapshot: VideoEdit)
    }

    init(session: VideoEditorSession, thumbnails: ThumbnailCache) {
        self.session = session
        self.thumbnails = thumbnails
        mapping = TimelineMapping(duration: session.duration, width: 600)
        super.init(frame: CGRect(x: 0, y: 0, width: 800, height: Self.preferredHeight))
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        playheadLayer.zPosition = 10
        layer?.addSublayer(playheadLayer)
        thumbnails.onUpdate = { [weak self] in
            self?.needsDisplay = true
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.slider)
        setAccessibilityLabel("Timeline")
        setAccessibilityHelp("Move the playhead with the arrow keys; I and O set the trim, M adds a chapter, Z adds a zoom.")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.preferredHeight)
    }

    /// Redraws after the session changed.
    func sessionDidChange() {
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        updateAccessibilityValue()
    }

    // MARK: Geometry

    /// The x position of `time` in view coordinates.
    func x(for time: Double) -> CGFloat {
        Self.gutter + CGFloat(mapping.x(for: time))
    }

    /// The time at the view's `x`.
    func time(at x: CGFloat) -> Double {
        mapping.time(for: Double(x - Self.gutter))
    }

    var contentWidth: CGFloat {
        max(bounds.width - Self.gutter - Self.trailingInset, 1)
    }

    var stripRect: CGRect {
        CGRect(x: Self.gutter, y: Self.stripTop, width: contentWidth, height: Self.stripHeight)
    }

    var zoomLaneRect: CGRect {
        CGRect(x: Self.gutter, y: Self.zoomTop, width: contentWidth, height: Self.laneHeight)
    }

    var chapterLaneRect: CGRect {
        CGRect(x: Self.gutter, y: Self.chapterTop, width: contentWidth, height: Self.laneHeight)
    }

    /// A zoom's rectangle in its lane.
    func rect(for segment: ZoomSegment) -> CGRect {
        let lane = zoomLaneRect
        let start = x(for: segment.start)
        return CGRect(x: start, y: lane.minY + 2, width: max(x(for: segment.end) - start, 4), height: lane.height - 4)
    }

    override func layout() {
        super.layout()
        mapping.setWidth(Double(contentWidth))
        movePlayhead()
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        drawTimeline()
    }

    // MARK: Zooming the timeline

    func zoomIn() {
        zoom(by: 2, around: bounds.midX)
    }

    func zoomOut() {
        zoom(by: 0.5, around: bounds.midX)
    }

    func fit() {
        mapping.fit()
        mappingDidChange()
    }

    /// The zoom slider's position, 0 fitted to 1 zoomed in all the way.
    var zoomFraction: Double {
        get { mapping.zoomFraction }
        set {
            mapping.setZoomFraction(newValue)
            mappingDidChange()
        }
    }

    /// Keeps the playhead in view during playback.
    func reveal(_ time: Double) {
        let before = mapping
        mapping.reveal(time)
        if mapping != before {
            mappingDidChange()
        }
    }

    private func zoom(by factor: Double, around viewX: CGFloat) {
        mapping.zoom(by: factor, around: Double(viewX - Self.gutter))
        mappingDidChange()
    }

    private func mappingDidChange() {
        movePlayhead()
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        onMappingChange?()
    }

    override func magnify(with event: NSEvent) {
        zoom(by: 1 + event.magnification, around: convert(event.locationInWindow, from: nil).x)
    }

    override func scrollWheel(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            zoom(by: exp(Double(event.scrollingDeltaY) * (event.hasPreciseScrollingDeltas ? 0.01 : 0.1)), around: location.x)
            return
        }
        guard !mapping.isFitted else {
            super.scrollWheel(with: event)
            return
        }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        mapping.scroll(by: -Double(delta) * (event.hasPreciseScrollingDeltas ? 1 : 12))
        mappingDidChange()
    }

    // MARK: Playhead

    private func movePlayhead() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let x = x(for: playhead).rounded() - 1
        let visible = x >= Self.gutter - 1 && x <= bounds.width - Self.trailingInset + 1
        playheadLayer.isHidden = !visible
        playheadLayer.frame = CGRect(x: x, y: 2, width: 2, height: bounds.height - 4)
        CATransaction.commit()
        updateAccessibilityValue()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updatePlayheadColor()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updatePlayheadColor()
    }

    private func updatePlayheadColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            playheadLayer.backgroundColor = NSColor.systemRed.cgColor
        }
        playheadLayer.cornerRadius = 1
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let time = time(at: point.x)
        if let handle = trimHandle(at: point) {
            drag = handle == .start ? .trimStart(session.edit) : .trimEnd(session.edit)
            return
        }
        if zoomLaneRect.insetBy(dx: -4, dy: 0).contains(point) {
            mouseDownInZoomLane(at: point, time: time, clickCount: event.clickCount)
            return
        }
        if chapterLaneRect.insetBy(dx: -4, dy: 0).contains(point) {
            mouseDownInChapterLane(at: point, clickCount: event.clickCount)
            return
        }
        // Scrubbing keeps the selection, so a zoom's focus can be checked at other moments.
        drag = .scrub
        onSeek?(time, true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let time = time(at: convert(event.locationInWindow, from: nil).x)
        var edit = session.edit
        switch drag {
        case .scrub:
            onSeek?(time, true)
            return
        case let .trimStart(snapshot):
            edit = snapshot
            edit.setTrimStart(time, duration: session.duration)
            onSeek?(edit.range(duration: session.duration).lowerBound, true)
        case let .trimEnd(snapshot):
            edit = snapshot
            edit.setTrimEnd(time, duration: session.duration)
            onSeek?(edit.range(duration: session.duration).upperBound, true)
        case let .moveZoom(id, grab, snapshot):
            edit = snapshot
            edit.moveZoom(id, toStart: time - grab, duration: session.duration)
        case let .resizeZoomStart(id, snapshot):
            edit = snapshot
            edit.resizeZoom(id, start: time, duration: session.duration)
        case let .resizeZoomEnd(id, snapshot):
            edit = snapshot
            edit.resizeZoom(id, end: time, duration: session.duration)
        case let .moveChapter(id, snapshot):
            edit = snapshot
            edit.moveChapter(id, to: time, duration: session.duration)
            onSeek?(time, true)
        }
        session.preview(edit)
    }

    override func mouseUp(with _: NSEvent) {
        defer { drag = nil }
        switch drag {
        case .scrub:
            onSeek?(playhead, false)
        case let .trimStart(snapshot):
            session.finish(from: snapshot, actionName: "Set In Point")
            onSeek?(playhead, false)
        case let .trimEnd(snapshot):
            session.finish(from: snapshot, actionName: "Set Out Point")
            onSeek?(playhead, false)
        case let .moveZoom(_, _, snapshot):
            session.finish(from: snapshot, actionName: "Move Zoom")
        case let .resizeZoomStart(_, snapshot), let .resizeZoomEnd(_, snapshot):
            session.finish(from: snapshot, actionName: "Change Zoom")
        case let .moveChapter(_, snapshot):
            session.finish(from: snapshot, actionName: "Move Chapter")
            onSeek?(playhead, false)
        case nil:
            break
        }
    }

    private func mouseDownInZoomLane(at point: CGPoint, time: Double, clickCount: Int) {
        let segments = session.edit.zoomSegments
        if let segment = segments.first(where: { rect(for: $0).insetBy(dx: -4, dy: 0).contains(point) }) {
            session.select(.zoom(segment.id))
            let frame = rect(for: segment)
            if clickCount >= 2 {
                onSeek?(segment.start, false)
            } else if abs(point.x - frame.minX) <= 5, frame.width > 12 {
                drag = .resizeZoomStart(segment.id, snapshot: session.edit)
            } else if abs(point.x - frame.maxX) <= 5, frame.width > 12 {
                drag = .resizeZoomEnd(segment.id, snapshot: session.edit)
            } else {
                drag = .moveZoom(segment.id, grab: time - segment.start, snapshot: session.edit)
            }
            return
        }
        if clickCount >= 2 {
            session.addZoom(at: time)
        } else {
            session.select(nil)
        }
    }

    private func mouseDownInChapterLane(at point: CGPoint, clickCount: Int) {
        let nearest = session.edit.chapters.min { abs(x(for: $0.time) - point.x) < abs(x(for: $1.time) - point.x) }
        guard let marker = nearest, abs(x(for: marker.time) - point.x) <= 7 else {
            session.select(nil)
            return
        }
        session.select(.chapter(marker.id))
        onSeek?(marker.time, false)
        if clickCount >= 2 {
            onRenameChapter?(marker.id)
        } else {
            drag = .moveChapter(marker.id, snapshot: session.edit)
        }
    }

    /// Which trim handle `point` is on, if any.
    private func trimHandle(at point: CGPoint) -> TrimHandle? {
        guard stripRect.insetBy(dx: -Self.handleWidth, dy: -4).contains(point) else { return nil }
        let range = session.range
        let start = x(for: range.lowerBound)
        let end = x(for: range.upperBound)
        if point.x >= start - Self.handleWidth, point.x <= start + 2 {
            return .start
        }
        if point.x >= end - 2, point.x <= end + Self.handleWidth {
            return .end
        }
        return nil
    }

    private enum TrimHandle {
        case start
        case end
    }

    override func resetCursorRects() {
        let range = session.range
        let strip = stripRect
        addCursorRect(
            CGRect(x: x(for: range.lowerBound) - Self.handleWidth, y: strip.minY, width: Self.handleWidth + 2, height: strip.height),
            cursor: .resizeLeftRight
        )
        addCursorRect(
            CGRect(x: x(for: range.upperBound) - 2, y: strip.minY, width: Self.handleWidth + 2, height: strip.height),
            cursor: .resizeLeftRight
        )
        for segment in session.edit.zoomSegments {
            let frame = rect(for: segment)
            guard frame.width > 12 else { continue }
            addCursorRect(CGRect(x: frame.minX - 4, y: frame.minY, width: 9, height: frame.height), cursor: .resizeLeftRight)
            addCursorRect(CGRect(x: frame.maxX - 5, y: frame.minY, width: 9, height: frame.height), cursor: .resizeLeftRight)
        }
    }

    // MARK: Accessibility

    var onStep: ((Double) -> Void)?

    override func accessibilityPerformIncrement() -> Bool {
        onStep?(1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        onStep?(-1)
        return true
    }

    private func updateAccessibilityValue() {
        setAccessibilityValue("\(Timecode.spoken(playhead)) of \(Timecode.spoken(session.duration))")
    }
}
