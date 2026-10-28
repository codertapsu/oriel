import AppKit
import Carbon.HIToolbox
import CoreGraphics
import OrielCore

/// Conversions between Oriel's modifier set and the four flag types macOS uses.
public extension KeyCombo.Modifiers {
    init(cgFlags: CGEventFlags) {
        var modifiers: KeyCombo.Modifiers = []
        if cgFlags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if cgFlags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if cgFlags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if cgFlags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        self = modifiers
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var modifiers: KeyCombo.Modifiers = []
        if eventFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if eventFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if eventFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if eventFlags.contains(.command) {
            modifiers.insert(.command)
        }
        self = modifiers
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) {
            flags.insert(.maskControl)
        }
        if contains(.option) {
            flags.insert(.maskAlternate)
        }
        if contains(.shift) {
            flags.insert(.maskShift)
        }
        if contains(.command) {
            flags.insert(.maskCommand)
        }
        return flags
    }

    var eventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.control) {
            flags.insert(.control)
        }
        if contains(.option) {
            flags.insert(.option)
        }
        if contains(.shift) {
            flags.insert(.shift)
        }
        if contains(.command) {
            flags.insert(.command)
        }
        return flags
    }

    /// The `cmdKey | optionKey | controlKey | shiftKey` mask RegisterEventHotKey takes.
    var carbonFlags: UInt32 {
        var flags = 0
        if contains(.control) {
            flags |= controlKey
        }
        if contains(.option) {
            flags |= optionKey
        }
        if contains(.shift) {
            flags |= shiftKey
        }
        if contains(.command) {
            flags |= cmdKey
        }
        return UInt32(flags)
    }
}
