import CoreGraphics

/// Where a switcher that groups by app names its apps. A grid keeps one band above every row, labelled over each
/// group's tiles in that row, so groups pack the rows as tightly as ungrouped tiles do: a group never starts a row of
/// its own, which would leave single-window apps a mostly empty row each. A list puts a header row above each group.
nonisolated enum GroupHeaders: Sendable, Equatable {
    case none
    /// A band of `height` above every row (thumbnails).
    case aboveRows(height: CGFloat)
    /// A row of `height` above the first item of each group (titles); `starts` are those items' indexes, ascending.
    case aboveGroups(starts: [Int], height: CGFloat)
}
