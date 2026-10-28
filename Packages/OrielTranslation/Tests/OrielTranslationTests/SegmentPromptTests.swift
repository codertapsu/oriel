import Foundation
@testable import OrielTranslation
import Testing

struct SegmentPromptTests {
    @Test func instructionsNameTheLanguagesAndTheContract() {
        var request = TestSupport.request(["Hello"], source: "en", target: "ja")
        request.glossary = ["Oriel": "Oriel", "capture": "キャプチャ"]
        let instructions = SegmentPrompt.instructions(for: request)
        #expect(instructions.contains("Japanese (ja)") && instructions.contains("The source language is English."))
        #expect(instructions.contains(#"{"id": number, "translation": string}"#))
        #expect(instructions.contains(#""capture" → "キャプチャ""#))
        let detected = SegmentPrompt.instructions(for: TestSupport.request(["Hello"], source: nil, target: "de"))
        #expect(detected.contains("Detect the source language") && !detected.contains("glossary"))
    }

    @Test func segmentsAreCompactJSONWithStableKeys() {
        let json = SegmentPrompt.segmentsJSON([TranslationSegment(id: 3, text: "Say \"hi\"\nhttps://a.b/c")])
        #expect(json == #"[{"id":3,"text":"Say \"hi\"\nhttps://a.b/c"}]"#)
    }

    @Test func theSchemaWrapsTheArrayInAnObject() throws {
        let format = SegmentPrompt.responseFormat(includesSource: true)
        let schema = try #require((format["json_schema"] as? [String: Any])?["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object" && schema["required"] as? [String] == ["translations"])
        let items = try #require(((schema["properties"] as? [String: Any])?["translations"] as? [String: Any])?["items"] as? [String: Any])
        #expect(items["required"] as? [String] == ["id", "translation", "source"])
    }
}
