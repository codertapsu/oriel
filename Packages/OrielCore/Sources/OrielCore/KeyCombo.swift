/// A keyboard shortcut: one key plus modifiers. Stored in settings and registered by the hotkey engines.
public struct KeyCombo: Codable, Hashable, Sendable, CustomStringConvertible {
    /// A virtual key code (the `kVK_*` values of Carbon's Events.h).
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// The combination as macOS menus show it, e.g. `⌃⇧4`.
    public var description: String {
        modifiers.symbols + KeyCode.name(for: keyCode)
    }

    /// Modifier keys, independent of the AppKit, Carbon and CoreGraphics flag types.
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// In the order macOS draws them: ⌃⌥⇧⌘.
        public var symbols: String {
            var text = ""
            if contains(.control) {
                text += "⌃"
            }
            if contains(.option) {
                text += "⌥"
            }
            if contains(.shift) {
                text += "⇧"
            }
            if contains(.command) {
                text += "⌘"
            }
            return text
        }
    }
}
