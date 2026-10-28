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
    var context: FilterContext
    var screen: NSScreen
    /// The windows that passed the shortcut's filter, MRU first.
    var windows: [WindowEntry]
    var items: [SwitcherItem] = []
    var layout: SwitcherLayout
    var query = ""
    var selection = 0
    /// Bumped whenever `items` or `layout` change.
    var version = 0
    var displayNumbers: [UInt32: Int]

    var selectedItem: SwitcherItem? {
        items.indices.contains(selection) ? items[selection] : nil
    }
}
