import Hotkeys

/// The result of one input: whether the tap swallows the event, and what the controller does next.
nonisolated struct SwitcherTransition: Sendable, Equatable {
    var decision: TapDecision
    var effects: [SwitcherEffect]

    init(decision: TapDecision, effects: [SwitcherEffect] = []) {
        self.decision = decision
        self.effects = effects
    }

    static let pass = SwitcherTransition(decision: .pass)
    static let consume = SwitcherTransition(decision: .consume)

    static func pass(_ effects: [SwitcherEffect]) -> SwitcherTransition {
        SwitcherTransition(decision: .pass, effects: effects)
    }

    static func consume(_ effects: [SwitcherEffect]) -> SwitcherTransition {
        SwitcherTransition(decision: .consume, effects: effects)
    }
}
