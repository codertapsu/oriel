/// What Simplify would do: erase each line of text (the patches) and draw a bar in its place, in the text's colour.
nonisolated struct SimplifyPlan: Sendable, Equatable {
    var patches: [ImageLayer]
    var bars: [Bar]

    static let empty = SimplifyPlan(patches: [], bars: [])
}
