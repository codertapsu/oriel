/// A running application that can own windows, as `NSWorkspace` reports it.
nonisolated struct AppRecord: Sendable, Hashable, Identifiable {
    nonisolated enum Policy: Sendable, Hashable {
        /// A Dock app.
        case regular
        /// An agent (menu-bar app); it counts only when it owns layer-0 windows (PLAN §7.1.1 item 1).
        case accessory
    }

    var pid: Int32
    var bundleID: String?
    var name: String
    var policy: Policy
    var isHidden: Bool
    var isActive: Bool

    var id: Int32 {
        pid
    }

    init(pid: Int32, bundleID: String?, name: String, policy: Policy = .regular, isHidden: Bool = false, isActive: Bool = false) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.policy = policy
        self.isHidden = isHidden
        self.isActive = isActive
    }
}
