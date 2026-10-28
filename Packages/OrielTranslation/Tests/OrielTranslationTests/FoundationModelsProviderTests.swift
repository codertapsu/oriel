import Foundation
import FoundationModels
@testable import OrielTranslation
import Testing

struct FoundationModelsProviderTests {
    @Test(arguments: [
        (SystemLanguageModel.Availability.available, true),
        (.unavailable(.deviceNotEligible), false),
        (.unavailable(.appleIntelligenceNotEnabled), false),
        (.unavailable(.modelNotReady), false),
    ])
    func mapsTheSystemModelsAvailability(_ system: SystemLanguageModel.Availability, _ available: Bool) {
        let availability = FoundationModelsProvider.availability(from: system)
        #expect(availability.isAvailable == available)
        if !available {
            #expect(availability.action == .chooseAnotherProvider && !availability.message.isEmpty)
        }
    }

    @Test func matchesTargetsAgainstRegionalLanguages() {
        let supported = Set(["ja-JP", "zh-Hans-CN", "en-US"].map(Locale.Language.init(identifier:)))
        #expect(FoundationModelsProvider.supports(Locale.Language(identifier: "ja"), among: supported))
        #expect(FoundationModelsProvider.supports(Locale.Language(identifier: "zh-Hans"), among: supported))
        #expect(!FoundationModelsProvider.supports(Locale.Language(identifier: "zh-Hant"), among: supported))
        #expect(!FoundationModelsProvider.supports(Locale.Language(identifier: "ar"), among: supported))
    }

    @Test func chunksStayWithinAQuarterOfTheContextWindow() {
        #expect(FoundationModelsProvider.chunkBudget(contextSize: 4096) == 1024)
        #expect(FoundationModelsProvider.chunkBudget(contextSize: 100) == 256)
        let segments = (1 ... 200)
            .map { TranslationSegment(id: $0, text: String(repeating: $0.isMultiple(of: 2) ? "語" : "word ", count: 30)) }
        let budget = FoundationModelsProvider.chunkBudget(contextSize: 4096)
        let chunks = SegmentBatcher.batches(segments, maxCount: 40, maxCost: budget, cost: SegmentBatcher.estimatedTokens)
        #expect(chunks.flatMap(\.self) == segments)
        for chunk in chunks {
            #expect(chunk.count <= 40)
            #expect(chunk.count == 1 || chunk.map(SegmentBatcher.estimatedTokens).reduce(0, +) <= budget)
        }
    }

    /// Runs the on-device model for real, only with ORIEL_LIVE_PROVIDER_TESTS=1 on a Mac with Apple Intelligence.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ORIEL_LIVE_PROVIDER_TESTS"] == "1" && FoundationModelsProvider.gate.isOpen))
    func translatesOnDevice() async throws {
        let provider = FoundationModelsProvider(config: ProviderConfig(id: .foundationModels, kind: .foundationModels, temperature: 0))
        let result = try await TestSupport.collect(provider.translate(TestSupport.request(["Hello world", "Good morning"])))
        #expect(Set(result.translations.keys) == [1, 2])
        #expect(result.translations.values.allSatisfy { !$0.isEmpty })
    }
}
