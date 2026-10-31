import AppKit
import SharedUI
import Testing

/// The windows that the switcher lists for Oriel and that put Oriel in the Dock (PLAN §7.1.1, §10.1).
@MainActor
struct StandardWindowsTests {
    /// Settings, the editor and the tools' windows count; the switcher's panel, overlays, pins and floating panels do not.
    @Test func onlyTitledWindowsAtTheNormalLevelCount() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        #expect(StandardWindows.isStandard(window))
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        #expect(!StandardWindows.isStandard(panel))
        let overlay = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        #expect(!StandardWindows.isStandard(overlay))
        let pin = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        pin.level = .floating
        #expect(!StandardWindows.isStandard(pin))
    }

    /// A window that was made but never shown, or was closed, is not open: a closed Settings window that Oriel keeps
    /// for next time does not keep Oriel in the Dock.
    @Test func aWindowNeverShownIsNotOpen() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        #expect(!StandardWindows.isOpen(window))
        #expect(!StandardWindows.open.contains(window))
    }
}
