import PrivateAPIs

/// The real hot keys, through `CGSGetSymbolicHotKeyValue` and `CGSSetSymbolicHotKeyEnabled`.
nonisolated struct SystemSymbolicHotKeys: SymbolicHotKeyControlling {
    let apis: PrivateAPIs

    init(apis: PrivateAPIs = .shared) {
        self.apis = apis
    }

    func symbolicHotKeys() -> [SymbolicHotKey] {
        apis.symbolicHotKeys()
    }

    @discardableResult
    func setSymbolicHotKey(_ id: Int32, enabled: Bool) -> Bool {
        apis.setSymbolicHotKey(id, enabled: enabled)
    }
}
