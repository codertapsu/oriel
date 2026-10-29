import Foundation
@testable import OrielTranslation
import Testing

/// Placeholder tokens for providers without glossaries: the round trip, what counts as a surviving token, and the
/// fallback to the raw translation when a token is lost.
struct GlossaryProtectionTests {
    private let capture = GlossaryTerm(source: "capture", target: "キャプチャ")
    private let oriel = GlossaryTerm(source: "Oriel", target: "Oriel", isCaseSensitive: true)

    private func protection(_ texts: [String], terms: [GlossaryTerm]? = nil) -> GlossaryProtection {
        let segments = texts.enumerated().map { TranslationSegment(id: $0.offset + 1, text: $0.element) }
        return GlossaryProtection(segments: segments, terms: terms ?? [capture, oriel])
    }

    @Test func replacesTermsWithNumberedTokensAndBack() throws {
        let protection = protection(["Open the capture panel in Oriel.", "No terms here."])
        #expect(protection.segments.map(\.text) == ["Open the [[1]] panel in [[2]].", "No terms here."])
        let restored = try #require(protection.restore(TranslatedSegment(id: 1, text: "[[2]]で[[1]]パネルを開きます。")))
        #expect(restored.text == "Orielでキャプチャパネルを開きます。")
        #expect(protection.restore(TranslatedSegment(id: 2, text: "用語なし。"))?.text == "用語なし。")
    }

    @Test(arguments: [
        "［［1］］パネル", // full-width brackets
        "［［１］］パネル", // and digits
        "[[ 1 ]]パネル", // spaces inside
        "[1]パネル", // one pair of brackets lost
    ])
    func acceptsTokensTheEngineReformatted(_ translation: String) throws {
        let protection = protection(["The capture panel"])
        #expect(try #require(protection.restore(TranslatedSegment(id: 1, text: translation))).text == "キャプチャパネル")
    }

    @Test(arguments: [
        "パネル", // lost
        "[[1]][[1]]パネル", // doubled
        "[[I]]パネル", // mangled into a letter
        "[[ 1パネル", // unclosed
    ])
    func refusesTranslationsWhoseTokensDidNotSurvive(_ translation: String) {
        let protection = protection(["The capture panel"])
        #expect(protection.restore(TranslatedSegment(id: 1, text: translation)) == nil)
    }

    @Test func tokensNeverCollideWithCitationsInTheSource() throws {
        let protection = protection(["See [1] and [2]: capture it."])
        #expect(protection.segments.first?.text == "See [1] and [2]: [[3]] it.")
        let restored = try #require(protection.restore(TranslatedSegment(id: 1, text: "[1]と[2]を参照：[[3]]してください。")))
        #expect(restored.text == "[1]と[2]を参照：キャプチャしてください。")
    }

    @Test func carriesCapitalizationOverForTermsThatIgnoreCase() {
        let captura = GlossaryTerm(source: "capture", target: "captura")
        let token = { (original: String) in GlossaryProtection.Token(number: 1, term: captura, original: original) }
        #expect(GlossaryProtection.replacement(for: token("capture")) == "captura")
        #expect(GlossaryProtection.replacement(for: token("Capture")) == "Captura")
        #expect(GlossaryProtection.replacement(for: token("CAPTURE")) == "CAPTURA")
        let exact = GlossaryProtection.Token(number: 1, term: oriel, original: "Oriel")
        #expect(GlossaryProtection.replacement(for: exact) == "Oriel")
    }

    @Test func runFallsBackToTheRawTranslationForLostTokens() async throws {
        let segments = [
            TranslationSegment(id: 1, text: "Open the capture panel."),
            TranslationSegment(id: 2, text: "Then capture again."),
            TranslationSegment(id: 3, text: "Done."),
        ]
        var sent: [[String]] = []
        var emitted: [Int: String] = [:]
        try await GlossaryProtection.run(
            segments,
            terms: [capture],
            emit: { emitted[$0.id] = $0.text },
            translate: { batch, emit in
                sent.append(batch.map(\.text))
                for segment in batch {
                    // The engine keeps the token of segment 1, loses that of segment 2, and translates the raw text.
                    let text = segment.text.contains("[[") && segment.id == 2 ? "Puis encore." : "fr:\(segment.text)"
                    emit(TranslatedSegment(id: segment.id, text: text))
                }
            }
        )
        #expect(sent == [["Open the [[1]] panel.", "Then [[1]] again.", "Done."], ["Then capture again."]])
        #expect(emitted == [1: "fr:Open the キャプチャ panel.", 2: "fr:Then capture again.", 3: "fr:Done."])
    }

    @Test func runWithoutTermsInTheTextSendsTheSegmentsAsTheyAre() async throws {
        var sent: [String] = []
        try await GlossaryProtection.run(
            [TranslationSegment(id: 1, text: "Hello")],
            terms: [capture],
            emit: { _ in },
            translate: { batch, _ in sent += batch.map(\.text) }
        )
        #expect(sent == ["Hello"])
    }
}
