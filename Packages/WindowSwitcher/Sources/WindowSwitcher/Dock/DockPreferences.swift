import CoreFoundation

/// The Dock's own settings that decide when window counts can sit on its icons (PLAN §7.1.12): hidden automatically,
/// the Dock is out only while the pointer is in it; magnified, its icons move under the pointer.
nonisolated struct DockPreferences: Sendable, Equatable {
    var hidesAutomatically = false
    var magnifies = false

    /// Read from the Dock's preferences domain, refreshed first: the Dock writes them, not Oriel.
    static func current() -> DockPreferences {
        let domain = DockAccessibility.bundleIdentifier as CFString
        CFPreferencesAppSynchronize(domain)
        return DockPreferences(
            hidesAutomatically: CFPreferencesCopyAppValue("autohide" as CFString, domain) as? Bool ?? false,
            magnifies: CFPreferencesCopyAppValue("magnification" as CFString, domain) as? Bool ?? false
        )
    }

    /// Whether window counts show now: while the pointer is in the Dock (`isHovering`) a hidden Dock is out, and a
    /// magnified Dock's icons are away from where they were read.
    func showsCounts(isHovering: Bool) -> Bool {
        if magnifies, isHovering {
            return false
        }
        return !hidesAutomatically || isHovering
    }
}
