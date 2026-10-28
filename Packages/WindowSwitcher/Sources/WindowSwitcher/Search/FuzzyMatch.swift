/// A successful fuzzy match: how good it is and which characters matched, for highlighting.
nonisolated struct FuzzyMatch: Sendable, Equatable {
    var score: Int
    /// Offsets of the matched `Character`s in the searched text, ascending.
    var indices: [Int]
}
