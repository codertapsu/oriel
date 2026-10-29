/// Where the duplicate finder is, for the folder it was run on.
nonisolated enum DuplicateSearch: Sendable, Equatable {
    case idle
    case searching(DuplicateFinder.Progress?)
    case found([DuplicateGroup], folder: Int32)
}
