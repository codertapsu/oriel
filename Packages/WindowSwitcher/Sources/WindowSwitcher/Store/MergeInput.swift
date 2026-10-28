/// Everything `WindowMerger` combines: one consistent snapshot of the three sources (PLAN §7.1.1).
nonisolated struct MergeInput: Sendable {
    /// Apps that can own switcher windows: regular apps, and accessory apps that own layer-0 windows.
    var apps: [AppRecord]
    /// AX records per app: the listed ones and those reached on other Spaces.
    var axWindows: [Int32: [AXWindowRecord]]
    /// The window server's list, front to back.
    var serverWindows: [ServerWindowRecord]
    var spaces: SpaceSnapshot?
    var displays: [DisplayInfo]
    var rules: EligibilityRules
    /// With remote tokens, a window on another Space is shown only once an AX element proves it is a real
    /// window. Without them it is listed by app name, and focusing it activates the app (PLAN §7.1.1 item 2).
    var canReachOtherSpaces: Bool

    init(
        apps: [AppRecord],
        axWindows: [Int32: [AXWindowRecord]],
        serverWindows: [ServerWindowRecord],
        spaces: SpaceSnapshot?,
        displays: [DisplayInfo] = [],
        rules: EligibilityRules = EligibilityRules(),
        canReachOtherSpaces: Bool = true
    ) {
        self.apps = apps
        self.axWindows = axWindows
        self.serverWindows = serverWindows
        self.spaces = spaces
        self.displays = displays
        self.rules = rules
        self.canReachOtherSpaces = canReachOtherSpaces
    }
}
