import CoreGraphics
@testable import ScreenRuler
import Testing

struct AreaSelectionTests {
    private let retina = RulerDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)
    private let external = RulerDisplay(id: 2, frame: CGRect(x: 400, y: -100, width: 800, height: 600), scale: 1)

    private func drawn(
        _ start: CGPoint,
        _ end: CGPoint,
        on display: RulerDisplay,
        unit: RulerUnit = .points,
        square: Bool = false
    ) -> AreaSelection {
        var selection = AreaSelection(display: display)
        selection.begin(at: start, unit: unit, handleTolerance: 6)
        selection.drag(to: end, unit: unit, square: square)
        _ = selection.end()
        return selection
    }

    @Test func aDragDrawsOnTheGridOfTheUnit() {
        let points = drawn(CGPoint(x: 10.3, y: 20.6), CGPoint(x: 110.4, y: 70.2), on: retina)
        #expect(points.rect == CGRect(x: 10, y: 21, width: 100, height: 49))
        let pixels = drawn(CGPoint(x: 10.3, y: 20.6), CGPoint(x: 110.4, y: 70.2), on: retina, unit: .pixels)
        #expect(pixels.rect == CGRect(x: 10.5, y: 20.5, width: 100, height: 49.5))
        // Dragging up and to the left works the same way.
        #expect(drawn(CGPoint(x: 600, y: 200), CGPoint(x: 500, y: 100), on: external).rect == CGRect(
            x: 500,
            y: 100,
            width: 100,
            height: 100
        ))
    }

    @Test func shiftMakesASquareThatStaysOnTheDisplay() {
        let square = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 160, y: 130), on: retina, square: true)
        #expect(square.rect == CGRect(x: 100, y: 100, width: 60, height: 60))
        let atEdge = drawn(CGPoint(x: 350, y: 100), CGPoint(x: 420, y: 160), on: retina, square: true)
        #expect(atEdge.rect == CGRect(x: 350, y: 100, width: 50, height: 50), "as large as the display allows")
        let upward = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 70, y: 20), on: retina, square: true)
        #expect(upward.rect == CGRect(x: 20, y: 20, width: 80, height: 80))
    }

    @Test func aClickDrawsNothing() {
        var selection = AreaSelection(display: retina)
        selection.begin(at: CGPoint(x: 50, y: 50), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 51, y: 50), unit: .points, square: false)
        let drew = selection.end()
        #expect(!drew)
        #expect(selection.rect == nil)
    }

    @Test func theHandlesResizeAndTheInsideMoves() {
        let wide = RulerDisplay(id: 3, frame: CGRect(x: 0, y: 0, width: 1200, height: 500), scale: 1)
        var selection = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 180), on: wide)
        #expect(selection.handle(at: CGPoint(x: 201, y: 181), tolerance: 6) == .bottomRight)
        #expect(selection.handle(at: CGPoint(x: 150, y: 98), tolerance: 6) == .top)
        #expect(selection.handle(at: CGPoint(x: 100, y: 140), tolerance: 6) == .left)
        #expect(selection.handle(at: CGPoint(x: 150, y: 140), tolerance: 6) == nil)

        selection.begin(at: CGPoint(x: 200, y: 180), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 250.4, y: 230), unit: .points, square: false)
        _ = selection.end()
        #expect(selection.rect == CGRect(x: 100, y: 100, width: 150, height: 130))

        // A corner with Shift makes it square from the opposite corner.
        selection.begin(at: CGPoint(x: 250, y: 230), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 300, y: 240), unit: .points, square: true)
        _ = selection.end()
        #expect(selection.rect == CGRect(x: 100, y: 100, width: 200, height: 200))

        // An edge cannot be dragged past the opposite one.
        selection.begin(at: CGPoint(x: 100, y: 200), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 500, y: 200), unit: .points, square: false)
        _ = selection.end()
        #expect(selection.rect == CGRect(x: 299, y: 100, width: 1, height: 200))

        selection.select(CGRect(x: 600, y: 300, width: 100, height: 100))
        selection.begin(at: CGPoint(x: 650, y: 350), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 2000, y: 2000), unit: .points, square: false)
        _ = selection.end()
        #expect(selection.rect == CGRect(x: 1100, y: 400, width: 100, height: 100), "moved, not shrunk, against the display's corner")
    }

    @Test func arrowsNudgeAndResizeByOneUnit() {
        var selection = drawn(CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 150), on: retina)
        selection.nudge(dx: 1, dy: -10, unit: .points)
        #expect(selection.rect == CGRect(x: 101, y: 90, width: 100, height: 50))
        selection.nudge(dx: -1, dy: 0, unit: .pixels)
        #expect(selection.rect == CGRect(x: 100.5, y: 90, width: 100, height: 50))
        selection.resize(dWidth: 10, dHeight: -1, unit: .points)
        #expect(selection.rect == CGRect(x: 100.5, y: 90, width: 110, height: 49))
        selection.resize(dWidth: -500, dHeight: 0, unit: .pixels)
        #expect(selection.rect?.width == 0.5, "never smaller than one unit")
        selection.nudge(dx: 9999, dy: 0, unit: .points)
        #expect(selection.rect?.maxX == 400)
    }

    @Test func aDraggedEdgeSnapsWhereTheSnapSays() {
        var selection = AreaSelection(display: external)
        selection.begin(at: CGPoint(x: 500, y: 100), unit: .points, handleTolerance: 6)
        selection.drag(to: CGPoint(x: 603, y: 197), unit: .points, square: false) { point in
            CGPoint(x: abs(point.x - 600) < 5 ? 600 : point.x, y: point.y)
        }
        _ = selection.end()
        #expect(selection.rect == CGRect(x: 500, y: 100, width: 100, height: 97))
    }
}
