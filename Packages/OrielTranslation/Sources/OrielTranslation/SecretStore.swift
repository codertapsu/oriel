import OrielCore

/// Where provider API keys live. In the app this is the Keychain (`KeychainStore`, service `provider.<id>`); tests
/// use an in-memory store so they never touch the real Keychain.
protocol SecretStore: Sendable {
    func string(service: String, account: String) -> String?
    /// Stores `value`, or deletes the item when it is nil or empty.
    func setString(_ value: String?, service: String, account: String) throws
}

extension KeychainStore: SecretStore {}
