import AppKit

/// A standard button that takes the first click in a panel that never becomes key, such as Step Capture's palette,
/// so it works without first focusing the panel.
final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
