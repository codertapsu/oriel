/// Turns filtered windows into the items of one style, after search (PLAN §7.1.10). Pure.
nonisolated enum SwitcherItemBuilder {
    /// - Parameters:
    ///   - displayNumbers: every display's number, for badges on windows that are not on `panelDisplayID`;
    ///     empty with a single display.
    static func items(
        from entries: [WindowEntry],
        style: DisplayStyle,
        query: String,
        displayNumbers: [UInt32: Int] = [:],
        panelDisplayID: UInt32? = nil
    ) -> [SwitcherItem] {
        let ranked = SearchRanker.rank(entries, query: query)
        func item(_ window: RankedWindow, windowCount: Int) -> SwitcherItem {
            let info = window.entry.info
            let number = displayNumbers.count > 1 && info.displayID != panelDisplayID ? info.displayID.flatMap { displayNumbers[$0] } : nil
            let badges = WindowBadge.badges(for: info, displayNumber: number)
            return SwitcherItem(
                entry: window.entry,
                windowCount: windowCount,
                titleMatches: window.titleMatches,
                appMatches: window.appMatches,
                badges: badges,
                accessibilityLabel: SwitcherItem.accessibilityLabel(
                    title: style == .appIcons ? "" : info.title, appName: info.appName, badges: badges, windowCount: windowCount
                )
            )
        }
        guard style == .appIcons else {
            return ranked.map { item($0, windowCount: 1) }
        }
        // One item per app, in the order of each app's best-ranked (or most recent) window.
        var counts: [Int32: Int] = [:]
        for window in ranked {
            counts[window.entry.info.pid, default: 0] += 1
        }
        var seen = Set<Int32>()
        return ranked.compactMap { window in
            let pid = window.entry.info.pid
            guard seen.insert(pid).inserted else { return nil }
            return item(window, windowCount: counts[pid] ?? 1)
        }
    }
}
