import CoreGraphics
import Hotkeys

/// Recognizes a three-finger horizontal swipe from the event tap's gesture frames (PLAN §7.1.5). Pure, so it
/// is tested with synthetic sequences.
///
/// A sequence is rejected until every finger lifts when a fourth finger appears (a system Spaces swipe),
/// when fingers travel before the third one lands (a two-finger scroll or a drag), when a finger lifts before
/// recognition, or when the travel is mostly vertical. Recognition needs the average horizontal travel past
/// `activationDistance` with every finger moving the same way, at least `perFingerFraction` of it. Resting
/// fingers (a thumb on the trackpad) are ignored.
nonisolated struct GestureRecognizer: Sendable {
    nonisolated struct Configuration: Sendable, Equatable {
        /// Average horizontal travel, as a fraction of the trackpad's width, that opens the switcher.
        var activationDistance: CGFloat = 0.08
        /// Further travel per selection step.
        var stepDistance: CGFloat = 0.07
        /// The part of the activation distance each finger must travel in the same direction.
        var perFingerFraction: CGFloat = 0.5
        /// Horizontal travel must exceed vertical travel by this factor.
        var horizontalDominance: CGFloat = 1.5
        /// How far fingers may move before the third one lands.
        var landingDrift: CGFloat = 0.03
    }

    private enum State: Sendable, Equatable {
        case idle
        /// Fewer than three fingers so far, with where each one landed.
        case landing(start: [Int: CGPoint])
        /// Three fingers down, anchored where they were when the third landed.
        case tracking(anchors: [Int: CGPoint])
        /// Recognized; `lastStep` is the average travel at the last step.
        case active(anchors: [Int: CGPoint], lastStep: CGFloat)
        case rejected
    }

    var configuration = Configuration()
    private var state: State = .idle

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Whether a recognized swipe is in progress.
    var isActive: Bool {
        if case .active = state {
            return true
        }
        return false
    }

    /// Feeds one gesture frame: every finger touching the trackpad right now.
    mutating func feed(_ touches: [TouchSample]) -> [GestureEvent] {
        var fingers: [Int: CGPoint] = [:]
        for touch in touches where !touch.isResting {
            fingers[touch.identity] = touch.position
        }
        guard !fingers.isEmpty else {
            let wasActive = isActive
            state = .idle
            return wasActive ? [.ended] : []
        }
        switch state {
        case .idle:
            state = fingers.count >= 4 ? .rejected : fingers.count == 3 ? .tracking(anchors: fingers) : .landing(start: fingers)
            return []
        case var .landing(start):
            land(fingers, start: &start)
            return []
        case let .tracking(anchors):
            track(fingers, anchors: anchors)
        case let .active(anchors, lastStep):
            return advance(fingers, anchors: anchors, lastStep: lastStep)
        case .rejected:
            return []
        }
        if case let .active(anchors, _) = state {
            return [.began(averageTravel(fingers, from: anchors).x > 0 ? .forward : .backward)]
        }
        return []
    }

    private mutating func land(_ fingers: [Int: CGPoint], start: inout [Int: CGPoint]) {
        guard fingers.count < 4 else {
            state = .rejected
            return
        }
        for (identity, position) in fingers where start[identity] == nil {
            start[identity] = position
        }
        let drifted = fingers.contains { identity, position in
            start[identity].map { hypot(position.x - $0.x, position.y - $0.y) > configuration.landingDrift } ?? false
        }
        if drifted {
            state = .rejected
        } else {
            state = fingers.count == 3 ? .tracking(anchors: fingers) : .landing(start: start)
        }
    }

    private mutating func track(_ fingers: [Int: CGPoint], anchors: [Int: CGPoint]) {
        guard fingers.count == 3, Set(fingers.keys) == Set(anchors.keys) else {
            state = .rejected
            return
        }
        let travel = averageTravel(fingers, from: anchors)
        if abs(travel.y) >= configuration.activationDistance, abs(travel.y) > abs(travel.x) {
            state = .rejected
            return
        }
        guard abs(travel.x) >= configuration.activationDistance,
              abs(travel.x) >= configuration.horizontalDominance * abs(travel.y)
        else { return }
        let rightward = travel.x > 0
        let minimum = configuration.perFingerFraction * configuration.activationDistance
        let together = anchors.allSatisfy { identity, anchor in
            guard let position = fingers[identity] else { return false }
            let dx = position.x - anchor.x
            return (dx > 0) == rightward && abs(dx) >= minimum
        }
        if together {
            state = .active(anchors: anchors, lastStep: travel.x)
        }
    }

    private mutating func advance(_ fingers: [Int: CGPoint], anchors: [Int: CGPoint], lastStep: CGFloat) -> [GestureEvent] {
        if fingers.count >= 4 {
            state = .rejected
            return [.cancelled]
        }
        guard fingers.count == 3, Set(fingers.keys) == Set(anchors.keys) else {
            // Fingers are lifting: the swipe is over.
            state = .rejected
            return [.ended]
        }
        let travel = averageTravel(fingers, from: anchors).x
        var last = lastStep
        var events: [GestureEvent] = []
        while travel - last >= configuration.stepDistance {
            last += configuration.stepDistance
            events.append(.step(.forward))
        }
        while last - travel >= configuration.stepDistance {
            last -= configuration.stepDistance
            events.append(.step(.backward))
        }
        state = .active(anchors: anchors, lastStep: last)
        return events
    }

    private func averageTravel(_ fingers: [Int: CGPoint], from anchors: [Int: CGPoint]) -> CGPoint {
        var sum = CGPoint.zero
        var count: CGFloat = 0
        for (identity, anchor) in anchors {
            guard let position = fingers[identity] else { continue }
            sum.x += position.x - anchor.x
            sum.y += position.y - anchor.y
            count += 1
        }
        return count == 0 ? .zero : CGPoint(x: sum.x / count, y: sum.y / count)
    }
}
