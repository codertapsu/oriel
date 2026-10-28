import CoreGraphics
import Hotkeys
import Testing
@testable import WindowSwitcher

/// Synthetic gesture sequences (PLAN §7.1.5, §13.2): a three-finger horizontal swipe is recognized; four-finger
/// and two-finger sequences are rejected. Positions are normalized to the trackpad, origin bottom-left.
struct GestureRecognizerTests {
    /// Fingers land side by side at (0.3…0.5, 0.5), then all move by (dx, dy) in `steps` frames, then lift.
    private func swipe(
        fingers: Int,
        dx: CGFloat,
        dy: CGFloat = 0,
        steps: Int = 12,
        resting: Int? = nil,
        moving: Set<Int>? = nil
    ) -> [[TouchSample]] {
        let starts = (0 ..< fingers).map { CGPoint(x: 0.3 + 0.1 * CGFloat($0), y: 0.5) }
        var frames: [[TouchSample]] = []
        for step in 0 ... steps {
            let progress = CGFloat(step) / CGFloat(steps)
            var frame = starts.enumerated().map { index, start in
                let moves = moving?.contains(index) ?? true
                return TouchSample(
                    identity: index,
                    position: CGPoint(x: start.x + (moves ? dx * progress : 0), y: start.y + (moves ? dy * progress : 0)),
                    isResting: false
                )
            }
            if let resting {
                frame.append(TouchSample(identity: resting, position: CGPoint(x: 0.1, y: 0.1), isResting: true))
            }
            frames.append(frame)
        }
        frames.append([])
        return frames
    }

    private func events(_ frames: [[TouchSample]], recognizer: inout GestureRecognizer) -> [GestureEvent] {
        frames.flatMap { recognizer.feed($0) }
    }

    private func events(_ frames: [[TouchSample]]) -> [GestureEvent] {
        var recognizer = GestureRecognizer()
        return events(frames, recognizer: &recognizer)
    }

    @Test func aThreeFingerSwipeRightOpensStepsAndEndsOnLift() {
        let result = events(swipe(fingers: 3, dx: 0.35))
        #expect(result.first == .began(.forward))
        #expect(result.last == .ended)
        #expect(result.filter { $0 == .step(.forward) }.count >= 3)
        #expect(!result.contains(.cancelled))
    }

    @Test func aThreeFingerSwipeLeftGoesBackward() {
        let result = events(swipe(fingers: 3, dx: -0.2))
        #expect(result.first == .began(.backward))
        #expect(result.last == .ended)
    }

    @Test func aShortSwipeDoesNothing() {
        #expect(events(swipe(fingers: 3, dx: 0.05)) == [])
    }

    @Test(arguments: [2, 4, 5])
    func otherFingerCountsAreRejected(_ fingers: Int) {
        #expect(events(swipe(fingers: fingers, dx: 0.4)) == [])
        #expect(events(swipe(fingers: fingers, dx: -0.4)) == [])
    }

    @Test func aFourthFingerCancelsARecognizedSwipe() {
        var frames = Array(swipe(fingers: 3, dx: 0.2).dropLast())
        let last = frames[frames.count - 1]
        frames.append(last + [TouchSample(identity: 9, position: CGPoint(x: 0.8, y: 0.5), isResting: false)])
        frames.append([])
        let result = events(frames)
        #expect(result.first == .began(.forward))
        #expect(result.contains(.cancelled))
        #expect(!result.contains(.ended))
    }

    @Test func fingersLandingOneByOneStillCount() {
        let positions = [CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.5, y: 0.5)]
        var frames: [[TouchSample]] = (1 ... 3).map { count in
            (0 ..< count).map { TouchSample(identity: $0, position: positions[$0], isResting: false) }
        }
        frames += Array(swipe(fingers: 3, dx: 0.2).dropFirst())
        #expect(events(frames).first == .began(.forward))
    }

    @Test func aTwoFingerScrollThatPicksUpAThirdFingerIsStillAScroll() {
        let scroll = Array(swipe(fingers: 2, dx: 0.15).dropLast())
        guard let lastScroll = scroll.last else {
            Issue.record("no frames")
            return
        }
        var frames = scroll
        frames.append(lastScroll + [TouchSample(identity: 2, position: CGPoint(x: 0.7, y: 0.5), isResting: false)])
        for step in 1 ... 10 {
            let dx = 0.03 * CGFloat(step)
            frames.append((0 ..< 3).map { index in
                let base = index < 2 ? lastScroll[index].position : CGPoint(x: 0.7, y: 0.5)
                return TouchSample(identity: index, position: CGPoint(x: base.x + dx, y: base.y), isResting: false)
            })
        }
        frames.append([])
        #expect(events(frames) == [])
    }

    @Test func aVerticalSwipeIsNotAHorizontalOne() {
        #expect(events(swipe(fingers: 3, dx: 0.02, dy: 0.3)) == [])
        #expect(events(swipe(fingers: 3, dx: 0.12, dy: 0.12)) == [])
    }

    @Test func everyFingerHasToTravel() {
        // One finger moves 0.36, so the average passes the threshold, but the other two stay put.
        #expect(events(swipe(fingers: 3, dx: 0.36, moving: [0])) == [])
    }

    @Test func aRestingThumbIsIgnored() {
        #expect(events(swipe(fingers: 3, dx: 0.2, resting: 7)).first == .began(.forward))
        // A resting thumb plus two moving fingers is still two fingers.
        #expect(events(swipe(fingers: 2, dx: 0.3, resting: 7)) == [])
    }

    @Test func aRejectedSequenceDoesNotBlockTheNextSwipe() {
        var recognizer = GestureRecognizer()
        #expect(events(swipe(fingers: 4, dx: 0.4), recognizer: &recognizer) == [])
        #expect(events(swipe(fingers: 3, dx: 0.2), recognizer: &recognizer).first == .began(.forward))
        #expect(!recognizer.isActive)
    }

    @Test func swipingBackAfterRecognitionStepsBack() {
        var frames = Array(swipe(fingers: 3, dx: 0.3).dropLast())
        guard let peak = frames.last else {
            Issue.record("no frames")
            return
        }
        for step in 1 ... 10 {
            frames.append(peak.map { touch in
                TouchSample(
                    identity: touch.identity,
                    position: CGPoint(x: touch.position.x - 0.03 * CGFloat(step), y: touch.position.y),
                    isResting: false
                )
            })
        }
        let result = events(frames)
        #expect(result.contains(.step(.backward)))
    }
}
