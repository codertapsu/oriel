import Carbon.HIToolbox
import Foundation
import OrielCore

/// What a key types on the current keyboard layout, for the switcher's search. The tap reports key codes,
/// which are layout-independent, so typed text comes from `UCKeyTranslate`. Text Input Sources are
/// main-thread only; the tap callback runs on the main thread, and the lookup happens only while the switcher
/// is open.
enum KeyTranslator {
    /// The text `keyCode` types with `modifiers`, or nil for keys that type nothing and for ⌘/⌥/⌃
    /// combinations, which are commands rather than text.
    static func characters(keyCode: UInt16, modifiers: KeyCombo.Modifiers) -> String? {
        guard modifiers.isSubset(of: .shift),
              let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              // The literal value of kTISPropertyUnicodeKeyLayoutData, which Swift 6 sees as shared mutable state.
              let property = TISGetInputSourceProperty(source, "TISPropertyUnicodeKeyLayoutData" as CFString)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let modifierState: UInt32 = modifiers.contains(.shift) ? UInt32((shiftKey >> 8) & 0xFF) : 0
        let status = UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifierState,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
        guard !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return text
    }
}
