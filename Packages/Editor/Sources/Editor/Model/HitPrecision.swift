/// How a point hit an item. Precise hits (a stroke, a label, a filled area) beat interior hits (the inside of an
/// unfilled rectangle or ellipse), so a big frame drawn last never hides what it surrounds.
nonisolated enum HitPrecision: Sendable, Equatable {
    case precise
    case interior
}
