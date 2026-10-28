import Foundation

/// The prompt side of the segment JSON contract (PLAN §7.7.4), shared by every LLM provider: the instruction, the
/// segments as JSON, and the JSON schema for servers with structured outputs.
enum SegmentPrompt {
    /// Ids from here up mark text that AI Vision found and OCR did not.
    static let firstVisionOnlyID = 1001

    static func instructions(for request: TranslationRequest) -> String {
        let target = LanguageCatalog.englishName(of: request.target)
        let targetCode = LanguageCatalog.code(for: request.target)
        let source = request.source.map { "The source language is \(LanguageCatalog.englishName(of: $0))." }
            ?? "Detect the source language of each segment."
        var lines: [String] = []
        if request.image == nil {
            lines += [
                "You are a translation engine. Translate the text of each segment into \(target) (\(targetCode)). \(source)",
                #"The input is a JSON array of objects {"id": number, "text": string}."#,
                #"Reply with only a JSON array of objects {"id": number, "translation": string}:"#
                    + " one object per input object, with exactly the same ids, in the same order.",
            ]
        } else {
            lines += [
                "You are a translation engine. The image is a screenshot. Read all of its text in reading order, including"
                    + " vertical, stylized or handwritten text, and translate it into \(target) (\(targetCode)). \(source)",
                #"The input is a JSON array of the text blocks OCR found, as {"id": number, "text": string}."#
                    + " OCR may have misread or missed text.",
                #"Reply with only a JSON array of objects {"id": number, "source": string, "translation": string}."#
                    + " Use the OCR id when the text matches an OCR block, and ids from \(firstVisionOnlyID) upwards for text OCR missed.",
            ]
        }
        lines += [
            "Preserve numbers, URLs, e-mail addresses, file paths, code, placeholders and line breaks (\\n).",
            "If a segment is already in \(target) or has nothing to translate, return it unchanged.",
            "Keep translations about as short as the original, because they replace it on screen.",
            "No commentary, no explanations, no Markdown.",
        ]
        if !request.glossary.isEmpty {
            let terms = request.glossary.sorted { $0.key < $1.key }.map { "\"\($0.key)\" → \"\($0.value)\"" }
            lines.append("Always translate these terms like this: \(terms.joined(separator: "; ")).")
        }
        return lines.joined(separator: "\n")
    }

    /// `[{"id":1,"text":"…"}]`, compact, with keys in a fixed order.
    static func segmentsJSON(_ segments: [TranslationSegment]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(segments) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// The OpenAI `response_format` for structured outputs. Its root has to be an object, so the array is wrapped
    /// (`{"translations": […]}`); the parser accepts both shapes.
    static func responseFormat(includesSource: Bool) -> [String: Any] {
        var properties: [String: Any] = ["id": ["type": "integer"], "translation": ["type": "string"]]
        var required = ["id", "translation"]
        if includesSource {
            properties["source"] = ["type": "string"]
            required.append("source")
        }
        let item: [String: Any] = ["type": "object", "properties": properties, "required": required, "additionalProperties": false]
        let schema: [String: Any] = [
            "type": "object",
            "properties": ["translations": ["type": "array", "items": item]],
            "required": ["translations"],
            "additionalProperties": false,
        ]
        return ["type": "json_schema", "json_schema": ["name": "translations", "strict": true, "schema": schema]]
    }
}
