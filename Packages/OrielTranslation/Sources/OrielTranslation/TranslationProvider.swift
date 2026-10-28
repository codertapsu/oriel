import Foundation

/// One translation backend (PLAN §7.7.1): Apple Translation, an OpenAI-compatible server, Apple Intelligence,
/// Anthropic, Google Translate or DeepL. Providers are values or actors, so they can be used from any task.
public protocol TranslationProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    var capabilities: ProviderCapabilities { get }

    /// Whether the provider can translate at all: key present, endpoint and model configured, OS and hardware able.
    /// Never contacts a server; "Test connection" does that.
    func availability() async -> ProviderAvailability

    /// Whether the provider can translate this pair. Defaults to `availability()`; Apple Translation also checks
    /// its language packs. A nil source means "not detected".
    func availability(source: Locale.Language?, target: Locale.Language) async -> ProviderAvailability

    /// Translates the request. The stream yields segments as they are ready, then one `.usage` event, and finishes;
    /// errors are `TranslationFailure`s. Cancelling the consuming task (or dropping the stream) cancels the work.
    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error>

    /// Checks the configuration against the real service and returns a one-line summary ("Connected · 12 models").
    func testConnection() async throws -> String
}

public extension TranslationProvider {
    func availability(source _: Locale.Language?, target _: Locale.Language) async -> ProviderAvailability {
        await availability()
    }
}
