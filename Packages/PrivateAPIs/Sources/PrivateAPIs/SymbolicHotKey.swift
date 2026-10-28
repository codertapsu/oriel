/// One of the system's symbolic hot keys (Cmd-Tab, Cmd-Shift-Tab, Mission Control …), as
/// `CGSGetSymbolicHotKeyValue` reports it.
public struct SymbolicHotKey: Sendable, Equatable {
    public let id: Int32
    public let virtualKeyCode: UInt16
    /// The raw modifier mask (the same bits as `CGEventFlags`).
    public let modifiers: UInt64
    public let isEnabled: Bool

    public init(id: Int32, virtualKeyCode: UInt16, modifiers: UInt64, isEnabled: Bool) {
        self.id = id
        self.virtualKeyCode = virtualKeyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}
