import Foundation
import FoundationModels
import OrielCore

/// Apple Intelligence's on-device model through `LanguageModelSession` (PLAN §7.7.2, priority 3). Segments are sent
/// in chunks of at most a quarter of the context window (4,096 tokens on macOS 26), each with a fresh session, so a
/// chunk and its answer stay well inside it; a chunk that still overflows is halved and retried.
///
/// The provider is hidden unless `SystemLanguageModel.default.availability == .available` (`gate`).
struct FoundationModelsProvider: TranslationProvider {
    let config: ProviderConfig

    private static let log = Log.logger("translation")

    private enum ModelErrorKind {
        case contextExceeded, declined, unsupportedLanguage, rateLimited, unavailable, other
    }

    var id: ProviderID {
        config.id
    }

    var displayName: String {
        config.displayName
    }

    var capabilities: ProviderCapabilities {
        config.kind.capabilities
    }

    /// Open only when the system model is available (Apple silicon, Apple Intelligence on, model downloaded).
    static var gate: FeatureGate {
        let availability = availability(from: SystemLanguageModel.default.availability)
        return availability.isAvailable ? .open : .closed(availability.message)
    }

    func availability() async -> ProviderAvailability {
        Self.availability(from: SystemLanguageModel.default.availability)
    }

    func availability(source _: Locale.Language?, target: Locale.Language) async -> ProviderAvailability {
        let availability = await availability()
        guard availability.isAvailable else { return availability }
        guard Self.supports(target, among: SystemLanguageModel.default.supportedLanguages) else {
            return .unavailable(
                "Apple Intelligence can't translate into \(LanguageCatalog.name(of: LanguageCatalog.code(for: target))) yet."
            )
        }
        return .available
    }

    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TranslationFailure.from(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async throws -> String {
        if let failure = await availability().failure {
            throw failure
        }
        return "Available on this Mac · context window \(SystemLanguageModel.default.contextSize) tokens"
    }

    /// Maps the system model's availability onto the provider's, with a reason the user can act on.
    static func availability(from availability: SystemLanguageModel.Availability) -> ProviderAvailability {
        switch availability {
        case .available:
            .available
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: .unavailable("This Mac can't run Apple Intelligence.")
            case .appleIntelligenceNotEnabled: .unavailable("Turn on Apple Intelligence in System Settings to use it for translation.")
            case .modelNotReady: .unavailable("The Apple Intelligence model is still downloading. Try again later.")
            @unknown default: .unavailable("Apple Intelligence isn't available on this Mac.")
            }
        }
    }

    /// The model lists languages with regions (`ja-JP`), so the target matches by language (and script for Chinese).
    static func supports(_ target: Locale.Language, among supported: Set<Locale.Language>) -> Bool {
        supported.contains { LanguageCatalog.isSameLanguage($0, target) }
    }

    /// Input tokens per chunk: a quarter of the context window leaves room for the instructions and the answer.
    static func chunkBudget(contextSize: Int) -> Int {
        max(256, contextSize / 4)
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        if let failure = await availability(source: request.source, target: request.target).failure {
            throw failure
        }
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        let chunks = SegmentBatcher.batches(
            request.segments, maxCount: 40, maxCost: Self.chunkBudget(contextSize: model.contextSize), cost: SegmentBatcher.estimatedTokens
        )
        for chunk in chunks {
            try Task.checkCancellation()
            try await translate(chunk, of: request, model: model, continuation: continuation)
        }
        continuation.yield(.usage(TranslationUsage(characters: request.characterCount)))
    }

    private func translate(
        _ chunk: [TranslationSegment],
        of request: TranslationRequest,
        model: SystemLanguageModel,
        continuation: SegmentEmitter.Continuation
    ) async throws {
        var part = request
        part.segments = chunk
        part.image = nil
        let session = LanguageModelSession(model: model, instructions: SegmentPrompt.instructions(for: part))
        var emitter = SegmentEmitter(continuation: continuation, expectedIDs: chunk.map(\.id))
        do {
            let options = GenerationOptions(temperature: config.temperature)
            for try await snapshot in session.streamResponse(to: SegmentPrompt.segmentsJSON(chunk), options: options) {
                emitter.feed(cumulative: snapshot.content)
            }
            emitter.finish()
        } catch {
            switch Self.classify(error) {
            case .contextExceeded where chunk.count > 1:
                Self.log.info("A chunk of \(chunk.count) segments overflowed the context window; splitting it")
                let half = chunk.count / 2
                try await translate(Array(chunk[..<half]), of: request, model: model, continuation: continuation)
                try await translate(Array(chunk[half...]), of: request, model: model, continuation: continuation)
            case .contextExceeded:
                throw TranslationFailure.badResponse("This text is too long for the on-device model.")
            case .declined:
                throw TranslationFailure.modelUnavailable("The on-device model declined to translate this text.")
            case .unsupportedLanguage:
                throw TranslationFailure.unavailable("Apple Intelligence doesn't support this language.")
            case .rateLimited:
                throw TranslationFailure.rateLimited(retryAfter: nil)
            case .unavailable:
                throw TranslationFailure.unavailable("The Apple Intelligence model isn't ready yet.")
            case .other:
                throw error
            }
        }
    }

    /// macOS 27 throws `LanguageModelError`; macOS 26 throws `LanguageModelSession.GenerationError`.
    private static func classify(_ error: any Error) -> ModelErrorKind {
        if #available(macOS 27, *), let error = error as? LanguageModelError {
            switch error {
            case .contextSizeExceeded: return .contextExceeded
            case .guardrailViolation, .refusal: return .declined
            case .unsupportedLanguageOrLocale: return .unsupportedLanguage
            case .rateLimited: return .rateLimited
            default: return .other
            }
        }
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize: return .contextExceeded
            case .guardrailViolation, .refusal: return .declined
            case .unsupportedLanguageOrLocale: return .unsupportedLanguage
            case .rateLimited: return .rateLimited
            case .assetsUnavailable: return .unavailable
            default: return .other
            }
        }
        return .other
    }
}
