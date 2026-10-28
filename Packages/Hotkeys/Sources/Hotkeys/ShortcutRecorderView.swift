import AppKit
import OrielCore

/// Click, then type a combination (PLAN §7.1.4): Esc cancels, Delete clears, reserved combinations are refused
/// with the reason as a tooltip, and conflicts with other Oriel shortcuts are flagged.
@MainActor
public final class ShortcutRecorderView: NSView {
    public var combo: KeyCombo? {
        didSet { needsDisplay = true }
    }

    /// Called with the new combination, or nil when cleared.
    public var onChange: ((KeyCombo?) -> Void)?
    /// Combinations that are allowed although reserved (⌘⇥ for the switcher).
    public var allowed: Set<KeyCombo> = []
    /// Other shortcuts in use, by what they do, to flag conflicts.
    public var inUse: [KeyCombo: String] = [:]

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    private var message: String?

    override public var acceptsFirstResponder: Bool {
        true
    }

    override public var intrinsicContentSize: NSSize {
        NSSize(width: 150, height: 24)
    }

    override public func mouseDown(with _: NSEvent) {
        isRecording = true
        message = nil
        window?.makeFirstResponder(self)
    }

    override public func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        // While recording, ⌘-combinations must reach keyDown instead of triggering menu items (⌘Q!).
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override public func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        let modifiers = KeyCombo.Modifiers(eventFlags: event.modifierFlags)
        switch RecorderDecision(keyCode: event.keyCode, modifiers: modifiers, allowed: allowed, inUse: inUse) {
        case .cancel:
            isRecording = false
        case .clear:
            commit(nil)
        case let .refuse(reason):
            message = reason
            toolTip = reason
            NSSound.beep()
            needsDisplay = true
        case let .accept(candidate, conflict):
            commit(candidate)
            if let conflict {
                toolTip = "Also used for \(conflict)."
            }
        }
    }

    private func commit(_ newCombo: KeyCombo?) {
        combo = newCombo
        isRecording = false
        message = nil
        toolTip = nil
        onChange?(newCombo)
    }

    override public func draw(_: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()
        let text: String = if isRecording {
            message ?? "Type shortcut…"
        } else if let combo {
            combo.description + (inUse[combo] != nil ? "  ⚠︎" : "")
        } else {
            "Record Shortcut"
        }
        let color: NSColor = (combo == nil && !isRecording) ? .secondaryLabelColor : .labelColor
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: color]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }

    override public func isAccessibilityElement() -> Bool {
        true
    }

    override public func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override public func accessibilityLabel() -> String? {
        combo.map { "Shortcut \($0.description)" } ?? "Record shortcut"
    }
}
