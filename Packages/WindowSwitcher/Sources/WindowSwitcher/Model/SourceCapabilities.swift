import PrivateAPIs

/// Which private paths a window source can take (PLAN §7.1.2). Each one has a public fallback.
nonisolated struct SourceCapabilities: Sendable, Equatable {
    /// `_AXUIElementGetWindow`; without it AX windows are matched to the server list by frame and title.
    var canMapWindowIDs: Bool
    /// `_AXUIElementCreateWithRemoteToken`; without it other-Space windows are listed by app name only.
    var canReachOtherSpaces: Bool
    /// SkyLight Spaces; without it there are no Space badges and "current Space" means "listed by AX".
    var canReadSpaces: Bool
    /// SkyLight focus; without it focusing asks the app to activate and raises through AX.
    var canFocusWindows: Bool

    init(canMapWindowIDs: Bool = true, canReachOtherSpaces: Bool = true, canReadSpaces: Bool = true, canFocusWindows: Bool = true) {
        self.canMapWindowIDs = canMapWindowIDs
        self.canReachOtherSpaces = canReachOtherSpaces
        self.canReadSpaces = canReadSpaces
        self.canFocusWindows = canFocusWindows
    }

    init(apis: PrivateAPIs) {
        canMapWindowIDs = apis.canMapElementsToWindows
        canReachOtherSpaces = apis.canReachOtherSpaces
        canReadSpaces = apis.canReadSpaces
        canFocusWindows = apis.canFocusWindows
    }
}
