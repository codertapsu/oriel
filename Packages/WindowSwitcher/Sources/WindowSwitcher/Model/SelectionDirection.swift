/// Which way a shortcut, a key or a swipe moves the selection.
nonisolated enum SelectionDirection: Sendable, Equatable {
    /// To the next item: the shortcut's next key, Tab, →, or a left-to-right swipe.
    case forward
    /// To the previous item: the reverse modifier, Shift-Tab, ←, or a right-to-left swipe.
    case backward

    var step: Int {
        self == .forward ? 1 : -1
    }
}
