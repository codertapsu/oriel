import Foundation
import OrielCore
import Translation

/// The Translation framework, headless (PLAN §7.7.3): `TranslationSession(installedSource:target:)` never downloads
/// anything and works offline once the pair's language pack is installed. Downloads go through
/// `LanguagePackDownloadView`, with the user's consent.
///
/// On macOS 26.4 and later the session (and the availability check) prefers the high-fidelity strategy when Apple
/// Intelligence is available and the user wants it, and low latency otherwise.
struct SystemTranslationBackend: AppleTranslationBackend {
    /// Whether to prefer `.highFidelity` where the OS offers strategies.
    let prefersHighFidelity: Bool

    /// Strategies arrived in macOS 26.4 (PLAN §7.7.2, rule 5: `#available` and a FeatureGate).
    static var strategyGate: FeatureGate {
        if #available(macOS 26.4, *) {
            return .open
        }
        return .closed("Translation strategies need macOS 26.4 or later.")
    }

    func status(from source: Locale.Language, to target: Locale.Language) async -> AppleLanguageStatus {
        let availability = if #available(macOS 26.4, *), Self.strategyGate.isOpen {
            LanguageAvailability(preferredStrategy: strategy)
        } else {
            LanguageAvailability()
        }
        switch await availability.status(from: source, to: target) {
        case .installed: return .installed
        case .supported: return .supported
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(
        _ segments: [TranslationSegment],
        from source: Locale.Language,
        to target: Locale.Language
    ) -> AsyncThrowingStream<TranslatedSegment, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let session = makeSession(source: source, target: target)
                let requests = segments.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id)) }
                do {
                    for try await response in session.translate(batch: requests) {
                        guard let id = response.clientIdentifier.flatMap(Int.init) else { continue }
                        continuation.yield(TranslatedSegment(id: id, text: response.targetText))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.failure(for: error, source: source, target: target))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @available(macOS 26.4, *)
    private var strategy: TranslationSession.Strategy {
        prefersHighFidelity ? .highFidelity : .lowLatency
    }

    private func makeSession(source: Locale.Language, target: Locale.Language) -> TranslationSession {
        if #available(macOS 26.4, *), Self.strategyGate.isOpen {
            return TranslationSession(installedSource: source, target: target, preferredStrategy: strategy)
        }
        return TranslationSession(installedSource: source, target: target)
    }

    static func failure(for error: any Error, source: Locale.Language, target: Locale.Language) -> TranslationFailure {
        let pair = (source: LanguageCatalog.code(for: source), target: LanguageCatalog.code(for: target))
        if error is CancellationError || TranslationError.alreadyCancelled ~= error {
            return .cancelled
        }
        if TranslationError.notInstalled ~= error {
            return .packNotInstalled(source: pair.source, target: pair.target)
        }
        let unsupported = [TranslationError.unsupportedLanguagePairing, .unsupportedSourceLanguage, .unsupportedTargetLanguage]
        if unsupported.contains(where: { $0 ~= error }) {
            return .unsupportedLanguagePair(source: pair.source, target: pair.target)
        }
        if TranslationError.unableToIdentifyLanguage ~= error {
            return .sourceLanguageUnknown
        }
        if TranslationError.nothingToTranslate ~= error {
            return .noText
        }
        return .badResponse(error.localizedDescription)
    }
}
