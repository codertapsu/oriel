/// Space layout and membership from SkyLight (PLAN §7.1.1 item 3), or nil when SkyLight is unavailable.
nonisolated struct SpaceSnapshot: Sendable, Equatable {
    /// One display's Spaces in Mission Control order.
    nonisolated struct Display: Sendable, Equatable {
        /// The CoreGraphics id, when the display's UUID matched an active display.
        var displayID: UInt32?
        var currentSpaceID: UInt64
        var spaceIDs: [UInt64]
        var fullScreenSpaceIDs: Set<UInt64>

        init(displayID: UInt32?, currentSpaceID: UInt64, spaceIDs: [UInt64], fullScreenSpaceIDs: Set<UInt64> = []) {
            self.displayID = displayID
            self.currentSpaceID = currentSpaceID
            self.spaceIDs = spaceIDs
            self.fullScreenSpaceIDs = fullScreenSpaceIDs
        }
    }

    var displays: [Display]
    /// Every Space a window is on, by window id. Empty for windows that are on no Space: minimized windows,
    /// inactive native tabs and the helper windows every app owns.
    var windowSpaces: [UInt32: [UInt64]]

    init(displays: [Display], windowSpaces: [UInt32: [UInt64]] = [:]) {
        self.displays = displays
        self.windowSpaces = windowSpaces
    }

    /// The Spaces visible right now, one per display.
    var currentSpaceIDs: Set<UInt64> {
        Set(displays.map(\.currentSpaceID))
    }
}
