/// What a history item's double-click and context menu ask for.
nonisolated enum HistoryCommand: Sendable, Equatable {
    /// Shows the capture in the Quick Access Overlay, with all its actions.
    case open
    case copy
    case save
    case pin
    case annotate
    case reveal
}
