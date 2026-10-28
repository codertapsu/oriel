@testable import Capture
import CoreGraphics
import Testing

struct SelectionEditorTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func editor(selecting rect: CGRect? = nil, snapping: EdgeSnapping = EdgeSnapping()) -> SelectionEditor {
        var editor = SelectionEditor(bounds: bounds, scale: 2, snapping: snapping)
        if let rect {
            editor.select(rect)
        }
        return editor
    }

    @Test func drawingAlignsEdgesToDevicePixels() {
        var editor = editor()
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 110.3, y: 60.2))
        let drew = editor.end()
        #expect(drew)
        #expect(editor.rect == CGRect(x: 10, y: 10, width: 100.5, height: 50))
        #expect(editor.pixelSize == CGSize(width: 201, height: 100))
        #expect(editor.phase == .idle)
    }

    @Test func aClickDrawsNothing() {
        var editor = editor()
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 11, y: 11))
        let drew = editor.end()
        #expect(!drew)
        #expect(editor.rect == nil)
    }

    @Test func drawingStaysOnItsDisplay() {
        var editor = editor()
        editor.begin(at: CGPoint(x: 1500, y: 970))
        editor.drag(to: CGPoint(x: 2000, y: 2000))
        editor.end()
        #expect(editor.rect == CGRect(x: 1500, y: 970, width: 12, height: 12))
    }

    @Test func arrowsNudgeByWholePixels() {
        var editor = editor(selecting: CGRect(x: 10, y: 10, width: 100, height: 50))
        editor.nudge(dx: 1, dy: 0)
        #expect(editor.rect?.minX == 10.5)
        editor.nudge(dx: 10, dy: -10)
        #expect(editor.rect == CGRect(x: 15.5, y: 5, width: 100, height: 50))
        editor.nudge(dx: -100_000, dy: 100_000)
        #expect(editor.rect == CGRect(x: 0, y: 932, width: 100, height: 50))
    }

    @Test func optionArrowsResizeFromTheTopLeftCorner() {
        var editor = editor(selecting: CGRect(x: 10, y: 10, width: 100, height: 50))
        editor.resize(dWidth: 1, dHeight: -1)
        #expect(editor.rect == CGRect(x: 10, y: 10, width: 100.5, height: 49.5))
        editor.resize(dWidth: -10000, dHeight: 0)
        #expect(editor.rect?.width == 0.5)
        editor.resize(dWidth: 100_000, dHeight: 100_000)
        #expect(editor.rect == CGRect(x: 10, y: 10, width: 1502, height: 972))
    }

    @Test func spaceDragMovesTheRectangleWhileDrawing() {
        var editor = editor()
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 60, y: 60))
        editor.drag(to: CGPoint(x: 80, y: 70), movesAnchor: true)
        #expect(editor.rect == CGRect(x: 30, y: 20, width: 50, height: 50))
        editor.drag(to: CGPoint(x: 100, y: 100))
        #expect(editor.rect == CGRect(x: 30, y: 20, width: 70, height: 80))
        // Moving into the edge keeps the size.
        editor.drag(to: CGPoint(x: -500, y: 100), movesAnchor: true)
        #expect(editor.rect == CGRect(x: 0, y: 20, width: 70, height: 80))
    }

    @Test func draggingInsideMovesAndHandlesResize() {
        var editor = editor(selecting: CGRect(x: 100, y: 100, width: 50, height: 50))
        editor.begin(at: CGPoint(x: 120, y: 120))
        editor.drag(to: CGPoint(x: 130, y: 125))
        editor.end()
        #expect(editor.rect == CGRect(x: 110, y: 105, width: 50, height: 50))

        editor.begin(at: CGPoint(x: 160, y: 155))
        #expect(editor.phase == .resizing(.bottomRight, original: CGRect(x: 110, y: 105, width: 50, height: 50)))
        editor.drag(to: CGPoint(x: 200, y: 185))
        #expect(editor.rect == CGRect(x: 110, y: 105, width: 90, height: 80))
        // Past the opposite corner the selection flips instead of turning negative.
        editor.drag(to: CGPoint(x: 50, y: 50))
        #expect(editor.rect == CGRect(x: 50, y: 50, width: 60, height: 55))
        editor.end()
    }

    @Test func handlesAreFoundCornersFirst() {
        let editor = editor(selecting: CGRect(x: 100, y: 100, width: 200, height: 100))
        #expect(editor.handle(at: CGPoint(x: 102, y: 98), tolerance: 6) == .topLeft)
        #expect(editor.handle(at: CGPoint(x: 200, y: 101), tolerance: 6) == .top)
        #expect(editor.handle(at: CGPoint(x: 297, y: 150), tolerance: 6) == .right)
        #expect(editor.handle(at: CGPoint(x: 150, y: 203), tolerance: 6) == .bottom)
        #expect(editor.handle(at: CGPoint(x: 99, y: 205), tolerance: 6) == .bottomLeft)
        #expect(editor.handle(at: CGPoint(x: 200, y: 150), tolerance: 6) == nil)
        #expect(editor.handle(at: CGPoint(x: 400, y: 150), tolerance: 6) == nil)
    }

    @Test func edgesSnapToNearbyWindowsUnlessCommandIsHeld() {
        let snapping = EdgeSnapping(frames: [CGRect(x: 300, y: 200, width: 400, height: 300)])
        var editor = editor(snapping: snapping)
        editor.begin(at: CGPoint(x: 10, y: 10))
        editor.drag(to: CGPoint(x: 296, y: 205))
        #expect(editor.rect == CGRect(x: 10, y: 10, width: 290, height: 190))
        editor.drag(to: CGPoint(x: 296, y: 205), snaps: false)
        #expect(editor.rect == CGRect(x: 10, y: 10, width: 286, height: 195))
        editor.drag(to: CGPoint(x: 280, y: 205))
        #expect(editor.rect?.maxX == 280)
        editor.end()
    }

    @Test func movedSelectionsSnapEitherEdge() {
        let snapping = EdgeSnapping(frames: [CGRect(x: 300, y: 200, width: 400, height: 300)])
        var editor = editor(selecting: CGRect(x: 100, y: 100, width: 50, height: 50), snapping: snapping)
        editor.begin(at: CGPoint(x: 120, y: 120))
        editor.drag(to: CGPoint(x: 273, y: 120))
        #expect(editor.rect == CGRect(x: 250, y: 100, width: 50, height: 50))
        editor.end()
    }

    @Test func selectingClipsToTheDisplay() {
        var editor = editor()
        editor.select(CGRect(x: 1400, y: 900, width: 500, height: 500))
        #expect(editor.rect == CGRect(x: 1400, y: 900, width: 112, height: 82))
        editor.select(CGRect(x: 5000, y: 0, width: 10, height: 10))
        #expect(editor.rect == nil)
    }

    @Test func snappingPicksTheClosestEdgeWithinTheThreshold() {
        let snapping = EdgeSnapping(xs: [100, 106], ys: [50], threshold: 8)
        #expect(snapping.snapX(104) == 106)
        #expect(snapping.snapX(90) == 90)
        #expect(snapping.snapY(43) == 50)
        #expect(snapping.offsetX(minX: 97, maxX: 150) == 3)
        #expect(snapping.offsetX(minX: 0, maxX: 20) == 0)
    }
}
