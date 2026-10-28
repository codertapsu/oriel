import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// What a click at a point selects, and where handles are.
@MainActor
struct HitTestingTests {
    private let tolerance: CGFloat = 4

    @Test func segmentDistance() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 10, y: 0)
        #expect(Geometry.distance(from: CGPoint(x: 5, y: 3), toSegmentFrom: start, to: end) == 3)
        #expect(Geometry.distance(from: CGPoint(x: -3, y: 4), toSegmentFrom: start, to: end) == 5)
        #expect(Geometry.distance(from: CGPoint(x: 13, y: 4), toSegmentFrom: start, to: end) == 5)
        #expect(Geometry.distance(from: CGPoint(x: 3, y: 4), toSegmentFrom: start, to: start) == 5)
    }

    @Test func linesAndArrowsAreHitAlongTheirStroke() {
        let line = AnnotationItem.line(Line(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 110, y: 10), color: .red, width: 4))
        #expect(line.hitTest(CGPoint(x: 60, y: 10), tolerance: tolerance) == .precise)
        #expect(line.hitTest(CGPoint(x: 60, y: 15.9), tolerance: tolerance) == .precise)
        #expect(line.hitTest(CGPoint(x: 60, y: 16.1), tolerance: tolerance) == nil)
        #expect(line.hitTest(CGPoint(x: 117, y: 10), tolerance: tolerance) == nil)

        let arrow = AnnotationItem.arrow(Arrow(start: CGPoint(x: 10, y: 50), end: CGPoint(x: 110, y: 50), color: .red, width: 4))
        // Beside the shaft, but within the head's width near the tip.
        #expect(arrow.hitTest(CGPoint(x: 105, y: 58), tolerance: tolerance) == .precise)
        #expect(arrow.hitTest(CGPoint(x: 40, y: 58), tolerance: tolerance) == nil)
    }

    @Test func unfilledShapesAreHitPreciselyOnTheOutlineAndWeaklyInside() {
        let rect = AnnotationItem.rect(Box(rect: CGRect(x: 0, y: 0, width: 100, height: 60), color: .red, width: 4))
        #expect(rect.hitTest(CGPoint(x: 0, y: 30), tolerance: tolerance) == .precise)
        #expect(rect.hitTest(CGPoint(x: 103, y: 30), tolerance: tolerance) == .precise)
        #expect(rect.hitTest(CGPoint(x: 50, y: 30), tolerance: tolerance) == .interior)
        #expect(rect.hitTest(CGPoint(x: 110, y: 30), tolerance: tolerance) == nil)

        let ellipse = AnnotationItem.ellipse(Box(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .red, width: 4))
        #expect(ellipse.hitTest(CGPoint(x: 50, y: 0), tolerance: tolerance) == .precise)
        #expect(ellipse.hitTest(CGPoint(x: 100, y: 50), tolerance: tolerance) == .precise)
        #expect(ellipse.hitTest(CGPoint(x: 50, y: 50), tolerance: tolerance) == .interior)
        // The bounding box's corner is outside the circle.
        #expect(ellipse.hitTest(CGPoint(x: 2, y: 2), tolerance: tolerance) == nil)
    }

    @Test func strokesLabelsStepsAndRegionsAreHitWhereTheyDraw() {
        let pen = AnnotationItem.freehand(FreehandPath(
            points: [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)], color: .red, width: 6
        ))
        #expect(pen.hitTest(CGPoint(x: 25, y: 5), tolerance: tolerance) == .precise)
        #expect(pen.hitTest(CGPoint(x: 55, y: 25), tolerance: tolerance) == .precise)
        #expect(pen.hitTest(CGPoint(x: 25, y: 25), tolerance: tolerance) == nil)

        let box = TextBox(origin: CGPoint(x: 10, y: 10), text: "Label", color: .red, fontSize: 20)
        let text = AnnotationItem.text(box)
        #expect(text.hitTest(CGPoint(x: box.frame.midX, y: box.frame.midY), tolerance: tolerance) == .precise)
        #expect(text.hitTest(CGPoint(x: box.frame.maxX + 10, y: box.frame.midY), tolerance: tolerance) == nil)

        let step = AnnotationItem.counter(Counter(center: CGPoint(x: 50, y: 50), number: 1, color: .red, radius: 16))
        #expect(step.hitTest(CGPoint(x: 50, y: 69), tolerance: tolerance) == .precise)
        #expect(step.hitTest(CGPoint(x: 50, y: 71), tolerance: tolerance) == nil)

        let blur = AnnotationItem.blur(Region(rect: CGRect(x: 0, y: 0, width: 40, height: 40), amount: 10))
        #expect(blur.hitTest(CGPoint(x: 20, y: 20), tolerance: tolerance) == .precise)
        #expect(blur.hitTest(CGPoint(x: 45, y: 20), tolerance: tolerance) == nil)
    }

    @Test func clicksPreferPreciseHitsThenTheTopmostItemAndAnnotationsOverEffects() throws {
        let frame = AnnotationItem.rect(Box(rect: CGRect(x: 0, y: 0, width: 200, height: 200), color: .red, width: 4))
        let step = AnnotationItem.counter(Counter(center: CGPoint(x: 100, y: 100), number: 1, color: .red, radius: 16))
        let blur = AnnotationItem.blur(Region(rect: CGRect(x: 60, y: 60, width: 80, height: 80), amount: 10))
        let lowerStep = AnnotationItem.counter(Counter(center: CGPoint(x: 30, y: 30), number: 2, color: .red, radius: 16))
        let upperStep = AnnotationItem.counter(Counter(center: CGPoint(x: 34, y: 30), number: 3, color: .red, radius: 16))
        var document = try TestImages.document()
        // The step is below the big frame and the blur in z-order, yet a click on it selects it.
        document.items = [step, lowerStep, upperStep, frame, blur]
        let session = EditorSession(document: document)
        #expect(session.item(at: CGPoint(x: 100, y: 100), tolerance: tolerance)?.id == step.id)
        #expect(session.item(at: CGPoint(x: 70, y: 70), tolerance: tolerance)?.id == blur.id)
        #expect(session.item(at: CGPoint(x: 160, y: 160), tolerance: tolerance)?.id == frame.id)
        #expect(session.item(at: CGPoint(x: 32, y: 30), tolerance: tolerance)?.id == upperStep.id)
        #expect(session.item(at: CGPoint(x: 250, y: 250), tolerance: tolerance) == nil)
    }

    @Test func handlesSitOnTheFrameOrTheLineEnds() {
        let rect = AnnotationItem.rect(Box(rect: CGRect(x: 10, y: 20, width: 100, height: 50), color: .red, width: 4))
        #expect(rect.handles.count == 8)
        #expect(rect.position(of: .topLeft) == CGPoint(x: 10, y: 20))
        #expect(rect.position(of: .bottom) == CGPoint(x: 60, y: 70))
        #expect(rect.handle(at: CGPoint(x: 108, y: 72), tolerance: 3) == .bottomRight)
        #expect(rect.handle(at: CGPoint(x: 60, y: 45), tolerance: 3) == nil)

        let arrow = AnnotationItem.arrow(Arrow(start: CGPoint(x: 5, y: 5), end: CGPoint(x: 90, y: 40), color: .red, width: 4))
        #expect(arrow.handles == [.start, .end])
        #expect(arrow.handle(at: CGPoint(x: 91, y: 41), tolerance: 3) == .end)

        let step = AnnotationItem.counter(Counter(center: .zero, number: 1, color: .red, radius: 10))
        #expect(step.handles.isEmpty)
    }

    @Test func resizingFlipsInsteadOfGoingNegativeAndScalesPenStrokes() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 50)
        #expect(Geometry.resize(rect, moving: .topLeft, to: CGPoint(x: 130, y: 80)) == CGRect(x: 110, y: 60, width: 20, height: 20))
        #expect(Geometry.resize(rect, moving: .right, to: CGPoint(x: 60, y: 999)) == CGRect(x: 10, y: 10, width: 50, height: 50))

        let pen = AnnotationItem.freehand(FreehandPath(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20)], color: .red, width: 2))
        guard case let .freehand(scaled) = pen.resized(moving: .bottomRight, to: CGPoint(x: 20, y: 40)) else {
            Issue.record("not a pen stroke")
            return
        }
        #expect(scaled.points == [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 40)])
    }

    @Test func boundsIncludeStrokeWidthAndArrowheads() {
        let rect = AnnotationItem.rect(Box(rect: CGRect(x: 10, y: 10, width: 100, height: 50), color: .red, width: 8))
        #expect(rect.bounds == CGRect(x: 6, y: 6, width: 108, height: 58))
        let arrow = Arrow(start: CGPoint(x: 0, y: 50), end: CGPoint(x: 100, y: 50), color: .red, width: 4)
        #expect(AnnotationItem.arrow(arrow).bounds.height >= arrow.headWidth)
        #expect(AnnotationItem.arrow(arrow).bounds.contains(arrow.end))
    }

    @Test func snappingAndSquares() {
        let start = CGPoint(x: 0, y: 0)
        let snapped = Geometry.snappedEnd(from: start, to: CGPoint(x: 10, y: 9))
        #expect(abs(snapped.x - snapped.y) < 0.0001)
        #expect(Geometry.rect(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 20, y: 40), square: true) == CGRect(
            x: 20,
            y: 20,
            width: 30,
            height: 30
        ))
        // Edges go to the nearest half point at 2×: 0.3 → 0.5, 0.74 → 0.5, 10.3 → 10.5, 10.84 → 11.
        #expect(Geometry.pixelAligned(CGRect(x: 0.3, y: 0.74, width: 10, height: 10.1), scale: 2) == CGRect(
            x: 0.5,
            y: 0.5,
            width: 10,
            height: 10.5
        ))
    }
}
