/// What `GestureRecognizer` reports for a three-finger horizontal swipe (PLAN §7.1.5).
nonisolated enum GestureEvent: Sendable, Equatable {
    /// Travel passed the activation distance: open the switcher, moving one step in `direction`.
    case began(SelectionDirection)
    /// Another step of travel.
    case step(SelectionDirection)
    /// The fingers lifted: commit.
    case ended
    /// A fourth finger joined (a system Spaces swipe): cancel.
    case cancelled
}
