/// One app's run of items in a switcher that groups by app: what its header shows and which items it covers.
nonisolated struct SwitcherGroup: Sendable, Equatable {
    var pid: Int32
    var appName: String
    var bundleID: String?
    /// The group's items, as indexes into the session's items.
    var items: Range<Int>
}
