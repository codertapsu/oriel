/// Raw facts about windows and the actions on them (PLAN §7.1.1, §13.2). `SystemWindowSource` reads
/// Accessibility, CGWindowList and SkyLight; tests hand the store a fake.
///
/// Reads return values only: AX elements never leave the implementation, which keeps them inside the AX actor.
nonisolated protocol WindowSource: Sendable {
    /// Changes worth re-reading for. Finishes when the source stops.
    var events: AsyncStream<WindowSourceEvent> { get }
    /// Which private paths are available.
    var capabilities: SourceCapabilities { get }

    /// Installs the workspace observers (AX observers are installed per app as apps are read).
    func start() async
    /// Removes every observer and finishes `events`.
    func stop() async

    /// Running apps with a regular or accessory activation policy.
    func applications() async -> [AppRecord]
    /// The windows the app lists through Accessibility (current Space, plus minimized ones).
    func accessibilityWindows(of pid: Int32) async -> AXWindowsResult
    /// AX records for windows the app does not list (other Spaces), from cached elements or remote tokens,
    /// within a strict element-id and time budget.
    func otherSpaceWindows(of pid: Int32, ids: Set<UInt32>) async -> [AXWindowRecord]
    /// The app's focused window.
    func focusedWindowID(of pid: Int32) async -> UInt32?
    /// Every window the window server knows, front to back.
    func serverWindows() async -> [ServerWindowRecord]
    /// Active displays.
    func displays() async -> [DisplayInfo]
    /// Space layout and the Spaces of the given windows; nil without SkyLight.
    func spaces(for windowIDs: [UInt32]) async -> SpaceSnapshot?
    /// Drops what the source keeps for a terminated app.
    func forget(pid: Int32) async
    /// Drops cached elements of windows that no longer exist.
    func prune(keeping windowIDs: Set<UInt32>) async

    /// Brings the window front and key, switching Space if needed (PLAN §7.1.3).
    func focus(_ window: WindowEntry) async -> Bool
    func perform(_ action: WindowAction, on window: WindowEntry) async -> Bool
    func setMinimized(_ minimized: Bool, window: WindowEntry) async -> Bool
    /// Asks the app to quit.
    func quit(pid: Int32) async -> Bool
}
