import Foundation
import OCR

/// Apple Translation (PLAN §7.7.2, priority 1): on-device and offline once the pair's language pack is installed.
/// It needs a known source language, so a request without one uses the language `LanguageDetector` finds in the
/// segments. Pairs whose pack is missing report `.packNotInstalled`, which the coordinator answers with the
/// download sheet. It has no glossary of its own, so glossary terms are protected with placeholder tokens.
struct AppleTranslationProvider: TranslationProvider {
    let id: ProviderID
    let displayName: String
    let backend: any AppleTranslationBackend

    init(id: ProviderID = .apple, displayName: String = ProviderKind.apple.displayName, backend: any AppleTranslationBackend) {
        self.id = id
        self.displayName = displayName
        self.backend = backend
    }

    var capabilities: ProviderCapabilities {
        ProviderKind.apple.capabilities
    }

    func availability() async -> ProviderAvailability {
        .available
    }

    func availability(source: Locale.Language?, target: Locale.Language) async -> ProviderAvailability {
        guard let source else { return .sourceLanguageUnknown }
        guard !LanguageCatalog.isSameLanguage(source, target) else { return .available }
        let pair = (source: LanguageCatalog.code(for: source), target: LanguageCatalog.code(for: target))
        switch await backend.status(from: source, to: target) {
        case .installed: return .available
        case .supported: return .packNotInstalled(source: pair.source, target: pair.target)
        case .unsupported: return .unsupportedLanguagePair(source: pair.source, target: pair.target)
        }
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
        let target = LanguageCatalog.systemLanguage
        let english = Locale.Language(identifier: "en")
        let source = LanguageCatalog.isSameLanguage(target, english) ? Locale.Language(identifier: "fr") : english
        let availability = await availability(source: source, target: target)
        let names = [source, target].map { LanguageCatalog.name(of: LanguageCatalog.code(for: $0)) }
        let pair = names.joined(separator: " → ")
        if let failure = availability.failure {
            if case .packNotInstalled = failure {
                return "Available · the \(pair) language pack isn't downloaded yet"
            }
            throw failure
        }
        return "Available on this Mac · \(pair) works offline"
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let source = request.source ?? LanguageDetector.dominantLanguage(of: request.segments.map(\.text)) else {
            throw TranslationFailure.sourceLanguageUnknown
        }
        if LanguageCatalog.isSameLanguage(source, request.target) {
            // Nothing to translate; Apple Translation would reject the pair.
            for segment in request.segments {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: segment.text)))
            }
            continuation.yield(.usage(TranslationUsage(characters: 0)))
            return
        }
        if let failure = await availability(source: source, target: request.target).failure {
            throw failure
        }
        // Apple Translation has no glossary, so terms travel as placeholder tokens (GlossaryProtection).
        var characters = 0
        try await GlossaryProtection.run(
            request.segments,
            terms: request.glossary.usableTerms,
            emit: { continuation.yield(.segment($0)) },
            translate: { segments, emit in
                characters += segments.reduce(0) { $0 + $1.text.count }
                for try await segment in backend.translate(segments, from: source, to: request.target) {
                    emit(segment)
                }
            }
        )
        continuation.yield(.usage(TranslationUsage(characters: characters)))
    }
}
