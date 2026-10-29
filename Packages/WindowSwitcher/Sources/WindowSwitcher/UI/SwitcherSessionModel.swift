import AppKit

/// What the open switcher shows: the filtered windows of one shortcut, ranked and grouped into items, the
/// layout, the selection and the search. The controller updates it synchronously in the tap callback; the
/// panel renders it on the next main-actor turn.
struct SwitcherSessionModel {
    /// Distinguishes sessions, so the panel knows when to start over.
    var token: Int
    var shortcutIndex: Int
    var style: DisplayStyle
    var filter: WindowFilter
    var grouping: WindowGrouping
    var context: FilterContext
    var screen: NSScreen
    /// The windows that passed the shortcut's filter, MRU first.
    var windows: [WindowEntry]
    var items: [SwitcherItem] = []
    /// Each app's run of items, when the shortcut groups by app and the style shows windows; empty otherwise.
    var groups: [SwitcherGroup] = []
    /// The keys named under the tiles; empty when Settings hides them.
    var hints: [KeyHint] = []
    var layout: SwitcherLayout
    var query = ""
    var selection = 0
    /// Bumped whenever `items` or `layout` change.
    var version = 0
    var displayNumbers: [UInt32: Int]

    var selectedItem: SwitcherItem? {
        items.indices.contains(selection) ? items[selection] : nil
    }

    /// Whether the items are grouped by app: the app-icons style is one tile per app already.
    var isGrouped: Bool {
        grouping == .byApp && style != .appIcons
    }
}
