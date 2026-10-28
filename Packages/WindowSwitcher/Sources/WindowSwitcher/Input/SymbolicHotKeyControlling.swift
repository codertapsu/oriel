import PrivateAPIs

/// Reads and switches the system's symbolic hot keys. `SystemSymbolicHotKeys` goes through `PrivateAPIs`;
/// tests use a fake, so they never touch the real Cmd-Tab.
nonisolated protocol SymbolicHotKeyControlling: Sendable {
    func symbolicHotKeys() -> [SymbolicHotKey]
    @discardableResult
    func setSymbolicHotKey(_ id: Int32, enabled: Bool) -> Bool
}
