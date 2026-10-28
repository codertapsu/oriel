import AppKit
import OrielCore
import os
import PrivateAPIs

/// Focusing per PLAN §7.1.3: SkyLight first (`bringToFront`, which also switches Space), then `AXRaise` and
/// `kAXMainAttribute`, unminimize, unhide. Activation has been cooperative since macOS 14 and our panel never
/// activates, so the public `NSRunningApplication.activate` is only the fallback.
nonisolated struct WindowFocuser: Sendable {
    let ax: AXClient
    let apis: PrivateAPIs

    func focus(_ window: WindowEntry) async -> Bool {
        let pid = window.info.pid
        let windowID = window.id
        let apis = apis
        var focused = await MainActor.run {
            apis.canFocusWindows && apis.bringToFront(pid: pid, windowID: windowID)
        }
        if !focused {
            focused = await MainActor.run {
                NSRunningApplication(processIdentifier: pid)?.activate(options: []) ?? false
            }
        }
        if window.isActionable {
            _ = await ax.raise(windowID: windowID)
            if window.info.isMinimized {
                _ = await ax.setMinimized(false, windowID: windowID)
            }
        }
        if window.info.isHidden {
            await MainActor.run {
                _ = NSRunningApplication(processIdentifier: pid)?.unhide()
            }
        }
        Log.logger("switcher").debug("focused window \(windowID) of pid \(pid): \(focused)")
        return focused
    }
}
