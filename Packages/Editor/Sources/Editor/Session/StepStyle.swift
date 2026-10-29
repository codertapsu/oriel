/// What the step tool puts down next: the marker's shape, its label style and whether it has a pointer. Its size and
/// colour are the toolbar's width and colour, as for every tool.
nonisolated struct StepStyle: Sendable, Equatable {
    var shape: StepShape = .circle
    var label: StepLabel = .numbers
    var pointer = false
}
