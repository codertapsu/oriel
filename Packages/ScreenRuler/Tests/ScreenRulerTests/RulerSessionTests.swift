import CoreGraphics
@testable import ScreenRuler
import Testing

/// The ruler's state machine, driven as the overlay drives it. (A mutating call cannot sit inside `#expect`, so each
/// effect is read into a constant first.)
struct RulerSessionTests {
    /// A 2× display 400 × 300 points, and a 1× one to its right.
    private let retina = RulerDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)
    private let external = RulerDisplay(id: 2, frame: CGRect(x: 400, y: 0, width: 800, height: 600), scale: 1)

    /// The Retina display's screenshot: white, with a black block over points 50 ..< 150 by 25 ..< 75.
    private var blockMap: EdgeMap {
        var bitmap = SyntheticBitmap(width: 800, height: 600)
        bitmap.fill(x: 100, y: 50, width: 200, height: 100, gray: 0)
        return bitmap.map
    }

    private func session(_ mode: RulerMode = .measureArea, edges: Bool = false) -> RulerSession {
        var session = RulerSession(
            displays: [retina, external],
            mode: mode,
            unit: .points,
            tolerance: 5,
            edgeStatus: edges ? .ready : .notPermitted
        )
        if edges {
            session.setEdgeMap(blockMap, for: retina.id)
        }
        return session
    }

    private func drag(
        _ session: inout RulerSession,
        from start: CGPoint,
        to end: CGPoint,
        square: Bool = false,
        snaps: Bool = true
    ) -> RulerEffect? {
        _ = session.mouseDown(at: start, clickCount: 1)
        session.mouseDragged(to: end, square: square, snaps: snaps)
        return session.mouseUp(at: end)
    }

    private func click(_ session: inout RulerSession, at point: CGPoint) {
        _ = session.mouseDown(at: point, clickCount: 1)
        _ = session.mouseUp(at: point)
    }

    @Test func tabAndDigitsSwitchModes() {
        var ruler = session(.dimensions)
        _ = ruler.handle(.nextMode)
        #expect(ruler.mode == .guides)
        _ = ruler.handle(.nextMode)
        #expect(ruler.mode == .measureArea)
        _ = ruler.handle(.previousMode)
        #expect(ruler.mode == .guides)
        _ = ruler.handle(.mode(.dimensions))
        #expect(ruler.mode == .dimensions)
    }

    @Test func measureAreaCopiesItsSizeInEitherUnit() {
        var ruler = session()
        let nothing = ruler.handle(.copy)
        #expect(nothing == .beep, "nothing measured yet")
        _ = drag(&ruler, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 340, y: 260))
        let points = ruler.handle(.copy)
        #expect(points == .copy("320 × 240 pt"))
        _ = ruler.handle(.toggleUnit)
        #expect(ruler.unit == .pixels)
        let pixels = ruler.handle(.copy)
        #expect(pixels == .copy("640 × 480 px"))
        let confirmed = ruler.handle(.confirm)
        #expect(confirmed == .copyAndClose("640 × 480 px"))
        let escaped = ruler.handle(.exit)
        #expect(escaped == .close)
    }

    @Test func arrowsNudgeOrResizeTheArea() {
        var ruler = session()
        _ = drag(&ruler, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 70))
        _ = ruler.handle(.arrow(dx: 10, dy: 1, resizes: false))
        #expect(ruler.area?.rect == CGRect(x: 30, y: 21, width: 100, height: 50))
        _ = ruler.handle(.arrow(dx: -1, dy: 0, resizes: true))
        #expect(ruler.area?.rect == CGRect(x: 30, y: 21, width: 99, height: 50))
        _ = ruler.handle(.delete)
        #expect(ruler.area?.rect == nil)
        let stray = ruler.handle(.arrow(dx: 1, dy: 0, resizes: false))
        #expect(stray == .beep)
    }

    @Test func anAreaStaysOnTheDisplayItWasStartedOn() {
        var ruler = session()
        _ = drag(&ruler, from: CGPoint(x: 300, y: 100), to: CGPoint(x: 700, y: 200))
        #expect(ruler.area?.display.id == retina.id)
        #expect(ruler.area?.rect == CGRect(x: 300, y: 100, width: 100, height: 100))
        // A new drag on the other display starts a new area there.
        _ = drag(&ruler, from: CGPoint(x: 500, y: 100), to: CGPoint(x: 600, y: 150))
        #expect(ruler.area?.display.id == external.id)
        let copied = ruler.handle(.copy)
        #expect(copied == .copy("100 × 50 pt"))
    }

    @Test func aDraggedCornerSnapsToEdgesUnlessCommandIsHeld() {
        var ruler = session(edges: true)
        _ = drag(&ruler, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 148, y: 73))
        #expect(ruler.area?.rect == CGRect(x: 10, y: 10, width: 140, height: 65), "onto the block's corner at 150, 75")
        _ = ruler.handle(.delete)
        _ = drag(&ruler, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 148, y: 73), snaps: false)
        #expect(ruler.area?.rect == CGRect(x: 10, y: 10, width: 138, height: 63))
    }

    @Test func dimensionsMeasureBetweenTheEdgesAroundThePointer() {
        var ruler = session(.dimensions, edges: true)
        ruler.pointerMoved(to: CGPoint(x: 100, y: 50))
        #expect(ruler.measurementText == "100 × 50 pt")
        ruler.pointerMoved(to: CGPoint(x: 20, y: 50))
        #expect(ruler.measurementText == "50 × 300 pt", "from the display's left edge to the block, and top to bottom")
        // The arrows move the point measured from, one unit at a time.
        _ = ruler.handle(.arrow(dx: 40, dy: 0, resizes: false))
        #expect(ruler.pointer == CGPoint(x: 60, y: 50))
        #expect(ruler.measurementText == "100 × 50 pt")
        ruler.pointerMoved(to: CGPoint(x: 500, y: 50))
        #expect(ruler.measurementText == nil, "no screenshot of the other display")
    }

    @Test func aClickKeepsTheBoxAndAnotherLetsItGo() {
        var ruler = session(.dimensions, edges: true)
        click(&ruler, at: CGPoint(x: 100, y: 50))
        #expect(ruler.pinned?.box == PixelRect(minX: 100, minY: 50, maxX: 300, maxY: 150))
        ruler.pointerMoved(to: CGPoint(x: 20, y: 280))
        #expect(ruler.measurementText == "100 × 50 pt", "the kept box is what is copied")
        click(&ruler, at: CGPoint(x: 120, y: 60))
        #expect(ruler.pinned == nil, "clicking the same box again lets it go")
        click(&ruler, at: CGPoint(x: 120, y: 60))
        #expect(ruler.pinned != nil)
        _ = ruler.handle(.delete)
        #expect(ruler.pinned == nil)
    }

    @Test func aBoxDrawnInDimensionsIsFittedToItsContent() {
        var ruler = session(.dimensions, edges: true)
        let effect = drag(&ruler, from: CGPoint(x: 30, y: 10), to: CGPoint(x: 200.2, y: 120))
        guard case let .fit(rect, displayID, tolerance) = effect else {
            Issue.record("expected a fit, got \(String(describing: effect))")
            return
        }
        #expect(rect == PixelRect(minX: 60, minY: 20, maxX: 401, maxY: 240))
        #expect(displayID == retina.id && tolerance == 13)
        ruler.pin(blockMap.contentBounds(in: rect, tolerance: tolerance), on: displayID)
        let copied = ruler.handle(.copy)
        #expect(copied == .copy("100 × 50 pt"))
        // Without a screenshot there is nothing to fit.
        var blind = session(.dimensions)
        let refused = drag(&blind, from: CGPoint(x: 30, y: 10), to: CGPoint(x: 200, y: 120))
        #expect(refused == .beep)
    }

    @Test func returnInDimensionsWithoutScreenRecordingAsksForIt() {
        var ruler = session(.dimensions)
        let asked = ruler.handle(.confirm)
        #expect(asked == .requestScreenRecording)
        _ = ruler.handle(.mode(.measureArea))
        let nothing = ruler.handle(.confirm)
        #expect(nothing == .beep)
    }

    @Test func bracketsChangeTheToleranceWithinItsRange() {
        var ruler = session(.dimensions, edges: true)
        let up = ruler.handle(.tolerance(delta: 1))
        #expect(up == .toleranceChanged(6))
        #expect(ruler.channelTolerance == 15)
        let down = ruler.handle(.tolerance(delta: -5))
        #expect(down == .toleranceChanged(1))
        let floor = ruler.handle(.tolerance(delta: -5))
        #expect(floor == .toleranceChanged(0))
        let below = ruler.handle(.tolerance(delta: -1))
        #expect(below == .beep)
        for _ in 0 ..< 20 {
            _ = ruler.handle(.tolerance(delta: 5))
        }
        #expect(ruler.tolerance == 50)
    }

    @Test func guidesAreAddedMovedMeasuredAndRemoved() {
        var ruler = session(.guides)
        click(&ruler, at: CGPoint(x: 600.4, y: 100))
        _ = ruler.handle(.flipGuide)
        click(&ruler, at: CGPoint(x: 900, y: 200))
        #expect(ruler.guides.guides(.vertical, on: external.id).map(\.position) == [600])
        #expect(ruler.guides.guides(.horizontal, on: external.id).map(\.position) == [200])
        ruler.pointerMoved(to: CGPoint(x: 700, y: 300))
        #expect(ruler.measurementText == "600 × 400 pt", "from the guides to the display's far edges")

        // Dragging a guide moves it; the arrows move the selected one.
        _ = ruler.mouseDown(at: CGPoint(x: 601, y: 400), clickCount: 1)
        ruler.mouseDragged(to: CGPoint(x: 650, y: 400), square: false, snaps: true)
        _ = ruler.mouseUp(at: CGPoint(x: 650, y: 400))
        #expect(ruler.guides.guides(.vertical, on: external.id).map(\.position) == [650])
        _ = ruler.handle(.arrow(dx: -10, dy: 0, resizes: false))
        #expect(ruler.guides.guides(.vertical, on: external.id).map(\.position) == [640])
        ruler.pointerMoved(to: CGPoint(x: 641, y: 50))
        #expect(ruler.cursor == .guide(.vertical))

        _ = ruler.handle(.delete)
        #expect(ruler.guides.guides(.vertical, on: external.id).isEmpty)
        _ = ruler.rightMouseDown(at: CGPoint(x: 1000, y: 201))
        #expect(ruler.guides.guides.isEmpty)
        let nothingLeft = ruler.handle(.deleteAll)
        #expect(nothingLeft == .beep)
    }

    @Test func theCursorFollowsWhatIsUnderIt() {
        var ruler = session()
        ruler.pointerMoved(to: CGPoint(x: 10, y: 10))
        #expect(ruler.cursor == .crosshair)
        _ = drag(&ruler, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 70))
        ruler.pointerMoved(to: CGPoint(x: 120, y: 70))
        #expect(ruler.cursor == .resize(.bottomRight))
        ruler.pointerMoved(to: CGPoint(x: 60, y: 40))
        #expect(ruler.cursor == .move)
    }

    @Test func switchingModesEndsADrag() {
        var ruler = session()
        _ = ruler.mouseDown(at: CGPoint(x: 20, y: 20), clickCount: 1)
        ruler.mouseDragged(to: CGPoint(x: 80, y: 80), square: false, snaps: true)
        _ = ruler.handle(.nextMode)
        #expect(ruler.area?.isDragging == false)
        #expect(ruler.area?.rect == CGRect(x: 20, y: 20, width: 60, height: 60))
    }

    /// Should a picture come back smaller than its display's pixel size, snapping and Dimensions read what there is
    /// instead of reaching past it.
    @Test func aPictureSmallerThanItsDisplayIsReadSafely() {
        var ruler = RulerSession(displays: [retina], mode: .measureArea, unit: .points, tolerance: 5, edgeStatus: .ready)
        let small = SyntheticBitmap(width: 100, height: 80).map
        ruler.setEdgeMap(small, for: retina.id)
        _ = drag(&ruler, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 390, y: 290))
        #expect(ruler.area?.rect == CGRect(x: 10, y: 10, width: 380, height: 280))
        _ = ruler.handle(.mode(.dimensions))
        ruler.pointerMoved(to: CGPoint(x: 390, y: 290))
        #expect(ruler.measurementText != nil)
        #expect(small.nearestColumnEdge(row: 5, near: 780, within: 10, tolerance: 5) == nil)
        #expect(small.nearestRowEdge(column: 5, near: 580, within: 10, tolerance: 5) == nil)
        #expect(SyntheticBitmap(width: 1, height: 1).map.nearestColumnEdge(row: 0, near: 0, within: 3, tolerance: 5) == nil)
    }

    @Test func aDoubleClickInsideTheAreaCopiesAndCloses() {
        var ruler = session()
        _ = drag(&ruler, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 70))
        let effect = ruler.mouseDown(at: CGPoint(x: 50, y: 50), clickCount: 2)
        #expect(effect == .copyAndClose("100 × 50 pt"))
    }
}
