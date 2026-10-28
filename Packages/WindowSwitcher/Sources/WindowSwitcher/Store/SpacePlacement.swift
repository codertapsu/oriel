/// Where a window sits among the Spaces (PLAN §7.1.1 item 3): on a visible Space or not, its 1-based index on
/// its display, the display, and whether its Space is a full-screen app's own.
nonisolated struct SpacePlacement: Sendable, Equatable {
    /// Nil when SkyLight could not say (no symbols, or the window is on no Space).
    var isOnCurrentSpace: Bool?
    var spaceIndex: Int?
    var displayID: UInt32?
    var isFullScreenSpace: Bool

    init(isOnCurrentSpace: Bool? = nil, spaceIndex: Int? = nil, displayID: UInt32? = nil, isFullScreenSpace: Bool = false) {
        self.isOnCurrentSpace = isOnCurrentSpace
        self.spaceIndex = spaceIndex
        self.displayID = displayID
        self.isFullScreenSpace = isFullScreenSpace
    }

    /// Places a window that is on `spaceIDs`. A window on several Spaces ("assign to all desktops") counts as
    /// current when any of them is visible.
    static func resolve(spaceIDs: [UInt64], in snapshot: SpaceSnapshot?) -> SpacePlacement {
        guard let snapshot, !spaceIDs.isEmpty else { return SpacePlacement() }
        let current = snapshot.currentSpaceIDs
        let isCurrent = spaceIDs.contains { current.contains($0) }
        // Report the visible Space when there is one, else the first Space the window is on.
        let primary = spaceIDs.first { current.contains($0) } ?? spaceIDs[0]
        guard let display = snapshot.displays.first(where: { $0.spaceIDs.contains(primary) }) else {
            return SpacePlacement(isOnCurrentSpace: isCurrent)
        }
        return SpacePlacement(
            isOnCurrentSpace: isCurrent,
            spaceIndex: display.spaceIDs.firstIndex(of: primary).map { $0 + 1 },
            displayID: display.displayID,
            isFullScreenSpace: display.fullScreenSpaceIDs.contains(primary)
        )
    }
}
