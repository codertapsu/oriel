import OrielCore

/// One window in the store: the public `WindowInfo` plus what the switcher needs internally.
nonisolated struct WindowEntry: Sendable, Hashable, Identifiable {
    var info: WindowInfo
    /// Whether an AX element is known, so close, minimize and full screen work. False for windows on other
    /// Spaces that no remote token reached; those are focused by id or by app (PLAN §7.1.1 item 2).
    var isActionable: Bool
    /// Every Space the window is on (empty when unknown).
    var spaceIDs: [UInt64]

    var id: UInt32 {
        info.id
    }

    init(info: WindowInfo, isActionable: Bool = true, spaceIDs: [UInt64] = []) {
        self.info = info
        self.isActionable = isActionable
        self.spaceIDs = spaceIDs
    }
}
