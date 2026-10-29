/// Turns filtered windows into the items of one style, after search (PLAN §7.1.10), grouped by app when the shortcut
/// asks for it (PLAN §7.1.11). Pure.
nonisolated enum SwitcherItemBuilder {
    /// - Parameters:
    ///   - displayNumbers: every display's number, for badges on windows that are not on `panelDisplayID`;
    ///     empty with a single display.
    ///   - grouping: `.byApp` puts each app's windows together, under a header; the app-icons style is one item per
    ///     app already and ignores it.
    static func items(
        from entries: [WindowEntry],
        style: DisplayStyle,
        query: String,
        displayNumbers: [UInt32: Int] = [:],
        panelDisplayID: UInt32? = nil,
        grouping: WindowGrouping = .ungrouped
    ) -> [SwitcherItem] {
        let ranked = SearchRanker.rank(entries, query: query)
        func item(_ window: RankedWindow, windowCount: Int, showsAppName: Bool = true) -> SwitcherItem {
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
                ),
                showsAppName: showsAppName
            )
        }
        guard style == .appIcons else {
            guard grouping == .byApp else { return ranked.map { item($0, windowCount: 1) } }
            return groupedByApp(ranked).map { item($0, windowCount: 1, showsAppName: false) }
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

    /// Each app's windows together, apps in the order of their first window, each app's windows in their own order.
    /// Stable, so with no search the apps follow their most recent window, and with one the best match stays first.
    static func groupedByApp(_ windows: [RankedWindow]) -> [RankedWindow] {
        var apps: [Int32] = []
        var windowsByApp: [Int32: [RankedWindow]] = [:]
        for window in windows {
            let pid = window.entry.info.pid
            if windowsByApp[pid] == nil {
                apps.append(pid)
            }
            windowsByApp[pid, default: []].append(window)
        }
        return apps.flatMap { windowsByApp[$0] ?? [] }
    }

    /// The runs of consecutive items of one app: the groups a grouped switcher labels.
    static func groups(of items: [SwitcherItem]) -> [SwitcherGroup] {
        var groups: [SwitcherGroup] = []
        for (index, item) in items.enumerated() {
            let info = item.entry.info
            if let last = groups.last, last.pid == info.pid, last.items.upperBound == index {
                groups[groups.count - 1].items = last.items.lowerBound ..< index + 1
            } else {
                groups.append(SwitcherGroup(pid: info.pid, appName: info.appName, bundleID: info.bundleID, items: index ..< index + 1))
            }
        }
        return groups
    }

    /// Where the selection starts in a grouped list, which is not in most-recent order: forward on the window used
    /// before the current one and backward on the least recent, wherever grouping put them, so a quick press still
    /// switches to the previous window. `windows` are the session's windows, most recent first.
    static func initialSelection(in items: [SwitcherItem], windows: [WindowEntry]) -> SwitcherStateMachine.InitialSelection? {
        guard windows.count > 1,
              let forward = items.firstIndex(where: { $0.id == windows[1].id }),
              let last = windows.last,
              let backward = items.firstIndex(where: { $0.id == last.id })
        else { return nil }
        return SwitcherStateMachine.InitialSelection(forward: forward, backward: backward)
    }
}
