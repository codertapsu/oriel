/// The explanations in the Window Switcher pane.
nonisolated enum SwitcherSettingsText {
    static let shortcuts = "Each shortcut shows all windows, the active app's, every window grouped by app, or the windows "
        + "of the display it opens on. Hold the modifiers and press the key to open the switcher; press it again to move "
        + "on, and add the step-back modifier to move back. While it is open: arrows move, typing searches, Return "
        + "switches, Esc cancels, W, M, F or Q with the modifier held close, minimize, toggle full screen or quit the "
        + "app, and 1–9 jump."

    static let needsScreenRecording = "Thumbnails and the preview need Screen & System Audio Recording. Without it the "
        + "switcher shows app icons and titles."

    static let dock = "Click a window to switch to it; its buttons close, minimize or make it full screen. Counts show on "
        + "apps with two or more windows, also while the switcher is off. While the Dock hides itself they show when it "
        + "is out, and with magnification on they step aside while the pointer is in the Dock. Thumbnails need Screen & "
        + "System Audio Recording."

    static let systemSwipe = "macOS uses three-finger horizontal swipes itself. In Trackpad settings, set “Swipe between "
        + "full-screen applications” to four fingers."

    static let commandTab = "While a shortcut uses ⌘⇥, the system app switcher (⌘⇥ and ⌘⇧⇥) is turned off. It comes "
        + "back when the shortcut changes, the switcher is turned off or Oriel quits, and after a crash at the next launch."

    static let exceptions = "Virtual machines and remote desktops keep their windows in the switcher, but while one is "
        + "frontmost the shortcuts go to it."

    static let stickyKeysOn = "Sticky Keys is on, so every shortcut keeps the switcher open: press Return or Space to "
        + "switch, Esc to cancel."

    static let stickyKeysOff = "With Sticky Keys on, every shortcut keeps the switcher open (Return or Space switches), "
        + "because a latched modifier is released right after the next key."

    static let spacesOn = "Focusing a window on another Space switches to that Space, because “When switching to an "
        + "application, switch to a Space with open windows for the application” is on."

    static let spacesOff = "“When switching to an application, switch to a Space with open windows for the application” "
        + "is off, so windows on other Spaces cannot be brought forward. Turn it on in Desktop & Dock → Mission Control."

    static let trackpadSettings = "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"
    static let desktopSettings = "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
}
