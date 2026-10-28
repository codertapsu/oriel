/// Which way a scrolling capture scrolls (PLAN §7.3, item 9). Horizontal runs the vertical algorithm on transposed
/// frames.
nonisolated enum ScrollDirection: String, Sendable, Equatable {
    case vertical
    case horizontal
}
