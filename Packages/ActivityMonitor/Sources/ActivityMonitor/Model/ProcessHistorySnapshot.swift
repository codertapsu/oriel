/// A copy of a `ProcessHistory` for the main thread: CPU percent and memory bytes, oldest first, NaN where unknown.
nonisolated struct ProcessHistorySnapshot: Sendable, Equatable {
    var cpu: [Float]
    var memory: [Float]
}
