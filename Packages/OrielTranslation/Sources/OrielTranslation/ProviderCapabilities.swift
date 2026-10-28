/// What a provider can do (PLAN §7.7.1). The UI uses it to show or hide controls, for example AI Vision.
public struct ProviderCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Results arrive while the provider is still working, so boxes fill in progressively.
    public static let streaming = ProviderCapabilities(rawValue: 1 << 0)
    /// Accepts the captured image ("AI Vision" mode).
    public static let imageInput = ProviderCapabilities(rawValue: 1 << 1)
    /// Works without a network connection.
    public static let offline = ProviderCapabilities(rawValue: 1 << 2)
    /// Finds the source language by itself.
    public static let autoDetect = ProviderCapabilities(rawValue: 1 << 3)
    /// Translates many segments in one request.
    public static let batch = ProviderCapabilities(rawValue: 1 << 4)
}
