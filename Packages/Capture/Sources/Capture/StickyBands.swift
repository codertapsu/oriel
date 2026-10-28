/// How many rows at the top (a sticky header) and at the bottom (a footer or toolbar) stayed put between two frames.
/// They are left out of the matching and drawn once (PLAN §7.3, item 6).
nonisolated struct StickyBands: Sendable, Equatable {
    var header: Int
    var footer: Int
}
