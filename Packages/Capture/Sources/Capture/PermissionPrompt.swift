import AppKit
import Permissions

/// What Capture says when a permission it needs is missing, or when something it tried did not work.
enum PermissionPrompt {
    /// Screen Recording is denied: why Oriel needs it, and a way to System Settings.
    static func explainScreenRecording(_ permissions: PermissionCenter) {
        let alert = NSAlert()
        alert.messageText = "Oriel needs Screen Recording to capture the screen"
        alert.informativeText = """
        Turn on Oriel in System Settings → Privacy & Security → Screen & System Audio Recording. \
        macOS may ask you to quit and reopen Oriel afterwards, and asks again from time to time whether Oriel may \
        keep recording.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if run(alert) == .alertFirstButtonReturn {
            permissions.openSystemSettings(for: .screenRecording)
        }
    }

    /// Automatic scrolling could not line up the frames. Returns true to try again in manual mode (PLAN §7.3, item 10).
    static func offerManualAfterLowConfidence() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Oriel could not line up the scrolled content"
        alert.informativeText = """
        Animations, videos, lazy loading or content that ignores scroll events get in the way of automatic \
        scrolling. Try manual mode: you scroll slowly, and Oriel stitches each part once it stops moving.
        """
        alert.addButton(withTitle: "Try Manual Mode")
        alert.addButton(withTitle: "Cancel")
        return run(alert) == .alertFirstButtonReturn
    }

    static func show(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "The capture did not work"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        run(alert)
    }

    @discardableResult
    private static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate()
        return alert.runModal()
    }
}
