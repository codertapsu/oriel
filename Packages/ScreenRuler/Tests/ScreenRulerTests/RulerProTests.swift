import CoreGraphics
@testable import ScreenRuler
import Testing

/// Without Oriel Pro, Guides, the edge tolerance and kept measurements ask for Pro, and Tab passes Guides by
/// (PLAN §19). (A mutating call cannot sit inside `#expect`, so each effect is read into a constant first.)
struct RulerProTests {
    private let retina = RulerDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)

    private func session(_ mode: RulerMode, edges: Bool = false) -> RulerSession {
        var session = RulerSession(
            displays: [retina],
            mode: mode,
            unit: .points,
            tolerance: 5,
            edgeStatus: edges ? .ready : .notPermitted
        )
        session.isProUnlocked = false
        if edges {
            var bitmap = SyntheticBitmap(width: 800, height: 600)
            bitmap.fill(x: 100, y: 50, width: 200, height: 100, gray: 0)
            session.setEdgeMap(bitmap.map, for: retina.id)
        }
        return session
    }

    @Test func tabPassesGuidesBy() {
        var ruler = session(.dimensions)
        _ = ruler.handle(.nextMode)
        #expect(ruler.mode == .measureArea)
        _ = ruler.handle(.previousMode)
        #expect(ruler.mode == .dimensions)
    }

    @Test func guidesAndTheToleranceAskForPro() {
        var ruler = session(.measureArea)
        let guides = ruler.handle(.mode(.guides))
        #expect(guides == .needsPro(.rulerGuides))
        #expect(ruler.mode == .measureArea)
        let tolerance = ruler.handle(.tolerance(delta: 1))
        #expect(tolerance == .needsPro(.rulerStyle))
        #expect(ruler.tolerance == 5)
    }

    @Test func keepingAMeasurementAsksForPro() {
        var ruler = session(.dimensions, edges: true)
        _ = ruler.mouseDown(at: CGPoint(x: 100, y: 50), clickCount: 1)
        let effect = ruler.mouseUp(at: CGPoint(x: 100, y: 50))
        #expect(effect == .needsPro(.keptMeasurements))
        #expect(ruler.pinned == nil)
    }
}
