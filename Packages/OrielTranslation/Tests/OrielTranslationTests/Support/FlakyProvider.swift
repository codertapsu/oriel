import Foundation
@testable import OrielTranslation
import Synchronization

/// A provider that tags every text with the target code, like `FakeProvider`, but can be told to fail one request.
final class FlakyProvider: TranslationProvider {
    let id: ProviderID = .apple
    let displayName = "Flaky"
    let capabilities: ProviderCapabilities = [.batch]
    private let state = Mutex<(requests: [TranslationRequest], failOn: Int?)>(([], nil))

    /// Fails the request with this number, from 1, counting every request ever made.
    func fail(onRequest number: Int?) {
        state.withLock { $0.failOn = number }
    }

    var requests: [TranslationRequest] {
        state.withLock { $0.requests }
    }

    func availability() async -> ProviderAvailability {
        .available
    }

    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error> {
        let fails = state.withLock { state in
            state.requests.append(request)
            return state.failOn == state.requests.count
        }
        let code = LanguageCatalog.code(for: request.target)
        return AsyncThrowingStream { continuation in
            if fails {
                continuation.finish(throwing: TranslationFailure.rateLimited(retryAfter: 30))
                return
            }
            for segment in request.segments {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: "[\(code)] \(segment.text)")))
            }
            continuation.yield(.usage(TranslationUsage(characters: request.characterCount)))
            continuation.finish()
        }
    }

    func testConnection() async throws -> String {
        "Flaky"
    }
}
