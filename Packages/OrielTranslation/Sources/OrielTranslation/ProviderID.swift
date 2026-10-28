/// Identifies one configured translation provider: a built-in one (`apple`, `foundation-models`) or one the user or
/// the bootstrap file added (`ollama`, `openai`, `deepl`, …). It is also the provider's Keychain service suffix
/// (`provider.<id>`) and the value of `oriel translate --provider`.
public struct ProviderID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String {
        rawValue
    }

    /// Apple Translation, on-device.
    public static let apple: ProviderID = "apple"
    /// Apple Intelligence's on-device language model.
    public static let foundationModels: ProviderID = "foundation-models"

    /// The Keychain service that holds this provider's API key.
    var keychainService: String {
        "provider.\(rawValue)"
    }
}
