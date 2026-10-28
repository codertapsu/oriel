/// How a scrolling capture moves the content (PLAN §7.3, items 3 and 9).
nonisolated enum ScrollingMode: Sendable, Equatable {
    /// Oriel posts scroll events at the region's centre; needs Accessibility.
    case automatic
    /// The user scrolls; Oriel adds every frame that has settled. For apps that ignore synthetic scrolls.
    case manual
}
