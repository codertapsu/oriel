import Foundation
import NaturalLanguage

/// Splits a document into requests a provider accepts (PLAN §17): segments are packed in order into chunks within
/// `ChunkLimits`, and never merged, so paragraph boundaries survive. Only a paragraph longer than a provider takes in
/// one piece is split, at sentences, then at spaces, then anywhere for scripts without spaces, and its pieces'
/// translations are joined again.
enum DocumentChunker {
    /// One request's worth of text from one segment.
    struct Piece: Equatable, Sendable {
        /// The id sent to the provider, unique within the document's translation.
        let requestID: Int
        let segmentID: Int
        /// Its place among the pieces of its segment, from 0.
        let part: Int
        let text: String
    }

    struct Chunk: Equatable, Sendable {
        let pieces: [Piece]

        var segments: [TranslationSegment] {
            pieces.map { TranslationSegment(id: $0.requestID, text: $0.text) }
        }

        var characterCount: Int {
            pieces.reduce(0) { $0 + $1.text.count }
        }
    }

    /// The translatable segments as chunks, request ids counting up from `firstRequestID`.
    static func chunks(_ segments: [DocumentSegment], limits: ChunkLimits, firstRequestID: Int = 1) -> [Chunk] {
        var chunks: [Chunk] = []
        var current: [Piece] = []
        var characters = 0
        var nextID = firstRequestID
        for segment in segments where segment.isTranslatable {
            for (part, text) in split(segment.text, maxCharacters: limits.maxSegmentCharacters).enumerated() {
                if !current.isEmpty, current.count >= limits.maxSegments || characters + text.count > limits.maxCharacters {
                    chunks.append(Chunk(pieces: current))
                    current = []
                    characters = 0
                }
                current.append(Piece(requestID: nextID, segmentID: segment.id, part: part, text: text))
                characters += text.count
                nextID += 1
            }
        }
        if !current.isEmpty {
            chunks.append(Chunk(pieces: current))
        }
        return chunks
    }

    /// `text` in pieces of at most `maxCharacters`: whole sentences where they fit, else words, else characters.
    static func split(_ text: String, maxCharacters: Int) -> [String] {
        let limit = max(1, maxCharacters)
        guard text.count > limit else { return [text] }
        var pieces: [String] = []
        var current = ""
        func add(_ unit: String) {
            if current.count + unit.count > limit, !current.isEmpty {
                pieces.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
            current += unit
        }
        for sentence in sentences(of: text) {
            guard sentence.count > limit else {
                add(sentence)
                continue
            }
            for word in words(of: sentence, limit: limit) {
                add(word)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            pieces.append(current.trimmingCharacters(in: .whitespaces))
        }
        return pieces.filter { !$0.isEmpty }
    }

    /// Joins the translations of one segment's pieces: with a space, or without one for a target written without
    /// spaces.
    static func join(_ parts: [String], target: Locale.Language) -> String {
        let code = target.languageCode?.identifier ?? ""
        let separator = ["ja", "zh", "th", "lo", "km", "my"].contains(code) ? "" : " "
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: separator)
    }

    /// The sentences, each with the space after it, so joining them gives the text back.
    private static func sentences(of text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        var end = text.startIndex
        tokenizer.enumerateTokens(in: text.startIndex ..< text.endIndex) { range, _ in
            sentences.append(String(text[end ..< range.upperBound]))
            end = range.upperBound
            return true
        }
        if end < text.endIndex {
            sentences.append(String(text[end...]))
        }
        return sentences.isEmpty ? [text] : sentences
    }

    /// Words with their trailing space; a run longer than `limit` (text without spaces) in `limit`-sized slices.
    private static func words(of sentence: String, limit: Int) -> [String] {
        var words: [String] = []
        var word = ""
        for character in sentence {
            word.append(character)
            if character.isWhitespace || word.count >= limit {
                words.append(word)
                word = ""
            }
        }
        if !word.isEmpty {
            words.append(word)
        }
        return words
    }
}
