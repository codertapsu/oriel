import CoreGraphics
import OrielCore

/// Combines Accessibility, the window server's list and SkyLight into the switcher's windows (PLAN §7.1.1).
/// Pure, so the rules are unit-tested with a fake source:
///
/// - AX records give titles, subroles and state; the server list gives layers, frames and z-order; SkyLight
///   gives Spaces.
/// - A record AX did not list counts only when the window is on another Space, minimized, or its app is
///   hidden. macOS 27 gives every app menu-bar-sized and hidden helper windows; they are on no Space or on a
///   visible one, so this rule and the subrole check keep them out.
nonisolated enum WindowMerger {
    static func merge(_ input: MergeInput) -> [WindowEntry] {
        let appsByPID = Dictionary(input.apps.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        let serverByID = Dictionary(input.serverWindows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var entries: [UInt32: WindowEntry] = [:]

        for app in input.apps where input.rules.accepts(app) {
            for record in input.axWindows[app.pid] ?? [] {
                guard let id = record.windowID ?? matchByFrame(record, pid: app.pid, in: input.serverWindows, claimed: entries),
                      entries[id] == nil
                else { continue }
                let server = serverByID[id]
                let spaceIDs = input.spaces?.windowSpaces[id] ?? []
                if !record.isListed, !record.isMinimized, !app.isHidden, !isOnOtherSpace(spaceIDs, input.spaces) {
                    continue
                }
                guard input.rules.accepts(record, layer: server?.layer, frame: server?.frame) else { continue }
                entries[id] = entry(for: record, id: id, app: app, server: server, spaceIDs: spaceIDs, input: input)
            }
        }

        if !input.canReachOtherSpaces, let spaces = input.spaces {
            for server in input.serverWindows where entries[server.id] == nil {
                let spaceIDs = spaces.windowSpaces[server.id] ?? []
                guard let app = appsByPID[server.pid], input.rules.accepts(app), input.rules.accepts(server),
                      isOnOtherSpace(spaceIDs, spaces)
                else { continue }
                entries[server.id] = fallbackEntry(for: server, app: app, spaceIDs: spaceIDs, input: input)
            }
        }

        var ordered: [WindowEntry] = []
        ordered.reserveCapacity(entries.count)
        for server in input.serverWindows {
            if let entry = entries.removeValue(forKey: server.id) {
                ordered.append(entry)
            }
        }
        ordered += entries.values.sorted { $0.id < $1.id }
        return ordered
    }

    /// Windows of `app` worth asking Accessibility about although it did not list them: on another Space, or
    /// anywhere when the app is hidden.
    static func otherSpaceCandidates(
        of app: AppRecord,
        listed: Set<UInt32>,
        serverWindows: [ServerWindowRecord],
        spaces: SpaceSnapshot?,
        rules: EligibilityRules
    ) -> Set<UInt32> {
        var candidates = Set<UInt32>()
        for server in serverWindows where server.pid == app.pid && !listed.contains(server.id) && rules.accepts(server) {
            let spaceIDs = spaces?.windowSpaces[server.id] ?? []
            if isOnOtherSpace(spaceIDs, spaces) || (app.isHidden && (spaces == nil || !spaceIDs.isEmpty)) {
                candidates.insert(server.id)
            }
        }
        return candidates
    }

    /// On at least one Space, none of them visible.
    static func isOnOtherSpace(_ spaceIDs: [UInt64], _ spaces: SpaceSnapshot?) -> Bool {
        guard let spaces, !spaceIDs.isEmpty else { return false }
        let current = spaces.currentSpaceIDs
        return !spaceIDs.contains { current.contains($0) }
    }

    private static func entry(
        for record: AXWindowRecord,
        id: UInt32,
        app: AppRecord,
        server: ServerWindowRecord?,
        spaceIDs: [UInt64],
        input: MergeInput
    ) -> WindowEntry {
        let placement = SpacePlacement.resolve(spaceIDs: spaceIDs, in: input.spaces)
        let frame = server?.frame ?? record.frame ?? .zero
        let title = [record.title, server?.title ?? ""].first { !$0.isEmpty } ?? app.name
        let info = WindowInfo(
            id: id,
            pid: app.pid,
            appName: app.name,
            bundleID: app.bundleID,
            title: title,
            frame: frame,
            isMinimized: record.isMinimized,
            isHidden: app.isHidden,
            isFullScreen: record.isFullScreen || placement.isFullScreenSpace,
            // AX lists the windows of the visible Spaces (and minimized ones), so a listing is the fallback.
            isOnCurrentSpace: placement.isOnCurrentSpace ?? record.isListed,
            spaceIndex: placement.spaceIndex,
            displayID: placement.displayID ?? displayID(for: frame, among: input.displays)
        )
        return WindowEntry(info: info, isActionable: true, spaceIDs: spaceIDs)
    }

    private static func fallbackEntry(
        for server: ServerWindowRecord,
        app: AppRecord,
        spaceIDs: [UInt64],
        input: MergeInput
    ) -> WindowEntry {
        let placement = SpacePlacement.resolve(spaceIDs: spaceIDs, in: input.spaces)
        let info = WindowInfo(
            id: server.id,
            pid: app.pid,
            appName: app.name,
            bundleID: app.bundleID,
            title: server.title.flatMap { $0.isEmpty ? nil : $0 } ?? app.name,
            frame: server.frame,
            isHidden: app.isHidden,
            isFullScreen: placement.isFullScreenSpace,
            isOnCurrentSpace: false,
            spaceIndex: placement.spaceIndex,
            displayID: placement.displayID ?? displayID(for: server.frame, among: input.displays)
        )
        return WindowEntry(info: info, isActionable: false, spaceIDs: spaceIDs)
    }

    /// Without `_AXUIElementGetWindow`: the app's unclaimed layer-0 window with the same frame (PLAN §7.1.2).
    /// Ambiguous for identical bounds; the first one wins.
    private static func matchByFrame(
        _ record: AXWindowRecord,
        pid: Int32,
        in serverWindows: [ServerWindowRecord],
        claimed: [UInt32: WindowEntry]
    ) -> UInt32? {
        guard let frame = record.frame else { return nil }
        let candidates = serverWindows.filter { server in
            server.pid == pid && server.layer == 0 && claimed[server.id] == nil
                && abs(server.frame.minX - frame.minX) <= 2 && abs(server.frame.minY - frame.minY) <= 2
                && abs(server.frame.width - frame.width) <= 2 && abs(server.frame.height - frame.height) <= 2
        }
        return (candidates.first { $0.title == record.title } ?? candidates.first)?.id
    }

    private static func displayID(for frame: CGRect, among displays: [DisplayInfo]) -> UInt32? {
        guard !displays.isEmpty, frame.width > 0, frame.height > 0 else { return nil }
        return ScreenGeometry.bestDisplay(for: frame, among: displays.map(\.bounds)).map { displays[$0].id }
    }
}
