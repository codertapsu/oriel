import Carbon.HIToolbox

/// Which key types a character in the current keyboard layout while ⌘ is held: ⌘V has to be posted with the key that
/// types "v", which on Dvorak or AZERTY is not the one where V is on a US keyboard, and some layouts ("Dvorak – QWERTY ⌘")
/// change when ⌘ is down.
enum KeyboardLayout {
    static func commandKeyCode(for character: Character) -> UInt16? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let wanted = String(character).lowercased()
        let modifiers = UInt32((cmdKey >> 8) & 0xFF)
        let keyboardType = UInt32(LMGetKbdType())
        return layoutData.withUnsafeBytes { buffer -> UInt16? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in UInt16(0) ..< 128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    code,
                    UInt16(kUCKeyActionDown),
                    modifiers,
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length).lowercased() == wanted {
                    return code
                }
            }
            return nil
        }
    }
}
