import AppKit
import ApplicationServices
import CoreGraphics

/// The permission checks Translate Under Cursor makes, through the public APIs CLAUDE.md rule 8 allows, neither of
/// which prompts. Tests stand in for them, and for the alert.
struct CursorPermissions {
    /// Screen & System Audio Recording, without which nothing can be read.
    var hasScreenRecording: @MainActor () -> Bool = { CGPreflightScreenCaptureAccess() }
    /// Accessibility, which macOS requires to see key presses in other apps (for Esc).
    var hasAccessibility: @MainActor () -> Bool = { AXIsProcessTrusted() }
    /// Says that Screen Recording is missing, and offers System Settings.
    var explainMissingScreenRecording: @MainActor () -> Void = Self.explainScreenRecording

    @MainActor
    static func explainScreenRecording() {
        let alert = NSAlert()
        alert.messageText = "Translate Under Cursor needs Screen Recording"
        alert.informativeText = """
        It reads the text under the pointer from the screen. Turn on Oriel in System Settings → Privacy & Security → \
        Screen & System Audio Recording; macOS may ask you to quit and reopen Oriel afterwards.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn,
              let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
