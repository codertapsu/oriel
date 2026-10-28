import CoreGraphics
import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

/// Helpers shared by the tests.
enum TestSupport {
    /// What a translation stream delivered.
    struct Collected {
        var segments: [TranslatedSegment] = []
        var usage: TranslationUsage?

        /// Id → text, the last text winning for repeated ids.
        var translations: [Int: String] {
            Dictionary(segments.map { ($0.id, $0.text) }) { _, last in last }
        }
    }

    static func collect(_ stream: AsyncThrowingStream<TranslationEvent, any Error>) async throws -> Collected {
        var collected = Collected()
        for try await event in stream {
            switch event {
            case let .segment(segment): collected.segments.append(segment)
            case let .usage(usage): collected.usage = usage
            }
        }
        return collected
    }

    /// The failure a stream ends with, or nil when it finishes normally.
    static func failure(of stream: AsyncThrowingStream<TranslationEvent, any Error>) async -> TranslationFailure? {
        do {
            _ = try await collect(stream)
            return nil
        } catch {
            return TranslationFailure.from(error)
        }
    }

    static func request(_ texts: [String], source: String? = "en", target: String = "fr", image: CGImage? = nil) -> TranslationRequest {
        TranslationRequest(
            segments: texts.enumerated().map { TranslationSegment(id: $0.offset + 1, text: $0.element) },
            source: source.map(Locale.Language.init(identifier:)),
            target: Locale.Language(identifier: target),
            image: image
        )
    }

    /// A solid-colour image.
    static func image(width: Int = 40, height: Int = 30, red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    /// An SSE body in OpenAI's chunk format, carrying `content` in pieces of `pieceLength` characters.
    static func openAIStream(_ content: String, pieceLength: Int = 5, usage: (prompt: Int, completion: Int)? = (42, 17)) -> String {
        let characters = Array(content)
        var lines: [String] = []
        for start in stride(from: 0, to: characters.count, by: pieceLength) {
            let piece = String(characters[start ..< min(start + pieceLength, characters.count)])
            let chunk: [String: Any] = ["object": "chat.completion.chunk", "choices": [["index": 0, "delta": ["content": piece]]]]
            lines.append("data: \(json(chunk))")
        }
        if let usage {
            let chunk: [String: Any] = ["choices": [], "usage": ["prompt_tokens": usage.prompt, "completion_tokens": usage.completion]]
            lines.append("data: \(json(chunk))")
        }
        lines.append("data: [DONE]")
        return lines.map { $0 + "\n\n" }.joined()
    }

    static func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
