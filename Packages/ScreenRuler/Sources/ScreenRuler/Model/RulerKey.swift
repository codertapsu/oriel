/// What a key press means to the ruler, whatever the keyboard layout (`RulerKeymap`).
nonisolated enum RulerKey: Equatable, Sendable {
    case nextMode
    case previousMode
    case mode(RulerMode)
    case toggleUnit
    /// ⌘C: copy the measurement and stay.
    case copy
    /// Return: copy the measurement and close; in Dimensions without Screen Recording, open System Settings.
    case confirm
    case exit
    /// An arrow: nudge by `dx`, `dy` units (10 with ⇧); with ⌥, resize instead.
    case arrow(dx: Int, dy: Int, resizes: Bool)
    /// `[` and `]`: the edge tolerance down or up, by 1 %, or by 5 % with ⇧.
    case tolerance(delta: Int)
    /// Space: the next guide is the other way.
    case flipGuide
    case guideOrientation(Guide.Orientation)
    /// ⌫: the selected guide, the kept box or the area goes.
    case delete
    /// ⌘⌫: every guide goes.
    case deleteAll
}
