/// An application exception (PLAN §1.2, §7.1.1 item 4), by bundle ID. A trailing `*` makes the rule a prefix,
/// so `com.parallels.*` covers every Parallels helper.
///
/// Two independent switches: `hidesWindows` drops the app's windows from the switcher; `ignoresShortcuts` lets
/// the switcher's shortcuts through to the app while it is frontmost, which is what virtual machines and
/// remote desktops need (⌥⇥ then reaches the guest OS).
nonisolated struct AppException: Codable, Sendable, Hashable, Identifiable {
    var bundleID: String
    var hidesWindows: Bool
    var ignoresShortcuts: Bool

    var id: String {
        bundleID
    }

    init(bundleID: String, hidesWindows: Bool = false, ignoresShortcuts: Bool = true) {
        self.bundleID = bundleID
        self.hidesWindows = hidesWindows
        self.ignoresShortcuts = ignoresShortcuts
    }

    /// Whether the rule covers `bundleID`. Case-insensitive, like bundle IDs themselves.
    func matches(_ candidate: String?) -> Bool {
        guard let candidate, !bundleID.isEmpty else { return false }
        let rule = bundleID.lowercased()
        let value = candidate.lowercased()
        if rule.hasSuffix("*") {
            return value.hasPrefix(rule.dropLast())
        }
        return value == rule
    }

    /// Virtual machines and remote-desktop clients: their windows stay in the switcher, but while one is
    /// frontmost the shortcuts belong to the guest or remote Mac.
    static let defaults: [AppException] = [
        "com.vmware.fusion",
        "com.vmware.horizon",
        "com.parallels.*",
        "org.virtualbox.app.VirtualBoxVM",
        "com.utmapp.UTM",
        "com.microsoft.rdc.macos",
        "com.citrix.receiver.icaviewer.mac",
        "com.teamviewer.TeamViewer",
        "com.realvnc.vncviewer",
        "com.apple.ScreenSharing",
    ].map { AppException(bundleID: $0) }
}

nonisolated extension [AppException] {
    /// The first rule for `bundleID`.
    func rule(for bundleID: String?) -> AppException? {
        first { $0.matches(bundleID) }
    }

    func hidesWindows(of bundleID: String?) -> Bool {
        rule(for: bundleID)?.hidesWindows ?? false
    }

    func ignoresShortcuts(in bundleID: String?) -> Bool {
        rule(for: bundleID)?.ignoresShortcuts ?? false
    }
}
