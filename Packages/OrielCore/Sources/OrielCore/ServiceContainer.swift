/// Shared services, as protocol existentials so tests can hand in fakes (PLAN §6.4). Built once by the app.
public struct ServiceContainer: Sendable {
    public var keychain: KeychainStore
    public var permissions: any PermissionChecking
    public var textRecognizer: (any TextRecognizing)?

    public init(keychain: KeychainStore, permissions: any PermissionChecking, textRecognizer: (any TextRecognizing)? = nil) {
        self.keychain = keychain
        self.permissions = permissions
        self.textRecognizer = textRecognizer
    }
}
