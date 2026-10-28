import Foundation
@testable import OrielTranslation
import Synchronization

/// A provider with canned behaviour: it prefixes every text with the target code, or fails.
final class FakeProvider: TranslationProvider {
    let id: ProviderID
    let displayName: String
    let capabilities: ProviderCapabilities
    let state: ProviderAvailability
    let failure: TranslationFailure?
    private let received = Mutex<[TranslationRequest]>([])

    init(
        id: ProviderID,
        capabilities: ProviderCapabilities = [.streaming, .batch],
        availability: ProviderAvailability = .available,
        failure: TranslationFailure? = nil
    ) {
        self.id = id
        displayName = "Fake \(id.rawValue)"
        self.capabilities = capabilities
        state = availability
        self.failure = failure
    }

    var requests: [TranslationRequest] {
        received.withLock { $0 }
    }

    func availability() async -> ProviderAvailability {
        state
    }

    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error> {
        received.withLock { $0.append(request) }
        let failure = failure
        let code = LanguageCatalog.code(for: request.target)
        return AsyncThrowingStream { continuation in
            if let failure {
                continuation.finish(throwing: failure)
                return
            }
            for segment in request.segments {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: "[\(code)] \(segment.text)")))
            }
            continuation.yield(.usage(TranslationUsage(characters: request.characterCount, inputTokens: 10, outputTokens: 20)))
            continuation.finish()
        }
    }

    func testConnection() async throws -> String {
        "Fake"
    }
}
