import AppKit

/// Where a request to quit Oriel came from (PLAN §10.1). Quit in the Dock's menu reaches Oriel as a quit event the Dock
/// sends; Oriel then closes its windows and stays in the menu bar, as it does for ⌘Q, which closes them without asking
/// to quit. Every other request quits: Quit in the menu-bar menu, logging out, restarting or shutting down, Quit & Reopen
/// in System Settings, a script or another app.
enum QuitRequest {
    static let dockBundleID = "com.apple.dock"

    /// Whether `event`, the Apple event being handled if any, is a quit event the Dock sent.
    static func isFromTheDock(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, let sender = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value, sender > 0
        else { return false }
        return isFromTheDock(event, senderBundleID: NSRunningApplication(processIdentifier: sender)?.bundleIdentifier)
    }

    /// Whether `event`, sent by the app with `senderBundleID`, is the Dock's Quit. A quit event that gives a reason
    /// (`kAEQuitReason`) comes from macOS ending the session. Pure.
    static func isFromTheDock(_ event: NSAppleEventDescriptor, senderBundleID: String?) -> Bool {
        let reason = AEKeyword(kAEQuitReason)
        return event.eventClass == AEEventClass(kCoreEventClass) && event.eventID == AEEventID(kAEQuitApplication)
            && event.paramDescriptor(forKeyword: reason) == nil && event.attributeDescriptor(forKeyword: reason) == nil
            && senderBundleID == dockBundleID
    }
}
