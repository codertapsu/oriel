import CoreGraphics
@testable import Editor
import OrielCore

/// Pointer input as the canvas view sends it, for tests.
extension EditorSession {
    /// A press, `steps` drag events along a straight line and a release.
    func drag(from start: CGPoint, to end: CGPoint, steps: Int = 8, modifiers: KeyCombo.Modifiers = []) {
        beginGesture(at: start, modifiers: modifiers)
        for step in 1 ... steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            continueGesture(
                to: CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction),
                modifiers: modifiers
            )
        }
        endGesture()
    }

    func click(at point: CGPoint, modifiers: KeyCombo.Modifiers = [], clickCount: Int = 1) {
        beginGesture(at: point, modifiers: modifiers, clickCount: clickCount)
        endGesture()
    }
}
