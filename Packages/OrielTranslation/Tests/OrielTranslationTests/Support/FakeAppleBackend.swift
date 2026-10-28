import Foundation
@testable import OrielTranslation
import Synchronization

/// Stands in for the Translation framework: a fixed pack status, and "translations" that tag the text with the pair.
final class FakeAppleBackend: AppleTranslationBackend {
    let status: AppleLanguageStatus
    private let calls = Mutex<[String]>([])

    init(status: AppleLanguageStatus) {
        self.status = status
    }

    /// `status` and `translate` calls, as `status en→ja` and `translate en→ja ×2`.
    var log: [String] {
        calls.withLock { $0 }
    }

    func status(from source: Locale.Language, to target: Locale.Language) async -> AppleLanguageStatus {
        calls.withLock { $0.append("status \(Self.pair(source, target))") }
        return status
    }

    func translate(
        _ segments: [TranslationSegment],
        from source: Locale.Language,
        to target: Locale.Language
    ) -> AsyncThrowingStream<TranslatedSegment, any Error> {
        calls.withLock { $0.append("translate \(Self.pair(source, target)) ×\(segments.count)") }
        let code = LanguageCatalog.code(for: target)
        return AsyncThrowingStream { continuation in
            for segment in segments.reversed() { // the framework does not promise order
                continuation.yield(TranslatedSegment(id: segment.id, text: "[\(code)] \(segment.text)"))
            }
            continuation.finish()
        }
    }

    private static func pair(_ source: Locale.Language, _ target: Locale.Language) -> String {
        "\(LanguageCatalog.code(for: source))→\(LanguageCatalog.code(for: target))"
    }
}
