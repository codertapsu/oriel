import Foundation

/// Reads LLM answers to the segment JSON contract (PLAN §7.7.4): a JSON array of `{"id": 1, "translation": "…"}`.
///
/// Feed it text while it streams in; each call returns the segments that became complete, so boxes fill in as the
/// answer arrives. It is deliberately tolerant of what models actually send: prose or code fences around the JSON, a
/// wrapping object (`{"translations": […]}` from structured outputs), string ids, keys in any order, `{"1": "…"}`
/// maps, unescaped quotes and raw line breaks inside strings, records written with brackets instead of braces, and
/// missing or repeated ids. Ids it does not know are passed on; the caller decides what to do with them.
struct SegmentParser {
    struct Segment: Equatable, Sendable {
        let id: Int
        let translation: String
        /// The source text, when the answer repeats it (AI Vision answers do).
        let source: String?
    }

    private enum Value {
        case string(String)
        case number(String)

        var text: String {
            switch self {
            case let .string(text), let .number(text): text
            }
        }

        var integer: Int? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return Int(trimmed) ?? Double(trimmed).flatMap { $0.isFinite ? Int($0) : nil }
        }
    }

    private enum Scan<Token> {
        case complete(Token, end: Int)
        case incomplete
    }

    private struct Record {
        var id: Int?
        var translation: String?
        var echoedText: String?
        var source: String?
        var emitted: (translation: String, source: String?)?
    }

    private var bytes: [UInt8] = []
    private var cursor = 0
    private var started = false
    private var lastString: String?
    private var pendingKey: String?
    private var record = Record()
    private var orphans: [String] = []
    private var foundAny = false

    /// Adds streamed text (a delta) and returns the segments it completed.
    mutating func feed(_ text: String) -> [Segment] {
        bytes.append(contentsOf: text.utf8)
        return scan(final: false)
    }

    /// For streams whose every element is the whole answer so far (FoundationModels snapshots).
    mutating func feed(cumulative text: String) -> [Segment] {
        let utf8 = Array(text.utf8)
        guard utf8.count >= bytes.count else {
            self = SegmentParser()
            return feed(text)
        }
        bytes.append(contentsOf: utf8[bytes.count...])
        return scan(final: false)
    }

    /// Ends the answer and returns what is left, falling back to positional matching against `expectedIDs` when the
    /// answer had no usable ids (a bare array of strings, one translation per line, or plain text for one segment).
    mutating func finish(expectedIDs: [Int]) -> [Segment] {
        var output = scan(final: true)
        output += flush()
        guard !foundAny else { return output }
        if !orphans.isEmpty {
            return Self.positional(orphans, expectedIDs)
        }
        if let strings = bareStringArray() {
            return Self.positional(strings, expectedIDs)
        }
        if !started {
            let text = Self.strippingCodeFences(UTF8Text.decode(bytes))
            let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if expectedIDs.count == 1, !text.isEmpty {
                return [Segment(id: expectedIDs[0], translation: text, source: nil)]
            }
            if expectedIDs.count > 1, lines.count == expectedIDs.count {
                return Self.positional(lines, expectedIDs)
            }
        }
        return output
    }

    // MARK: - Tokens

    private mutating func scan(final: Bool) -> [Segment] {
        var output: [Segment] = []
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if !started {
                guard byte == Byte.openBrace || byte == Byte.openBracket else {
                    cursor += 1
                    continue
                }
                started = true
            }
            switch byte {
            case Byte.space, Byte.tab, Byte.newline, Byte.carriageReturn:
                cursor += 1
            case Byte.quote:
                guard case let .complete(string, end) = readString(at: cursor, final: final) else { return output }
                cursor = end
                if let key = pendingKey {
                    pendingKey = nil
                    output += assign(.string(string), to: key)
                } else {
                    lastString = string
                }
            case Byte.colon:
                pendingKey = lastString
                lastString = nil
                cursor += 1
            case Byte.openBrace, Byte.closeBrace, Byte.closeBracket:
                output += flush()
                pendingKey = nil
                lastString = nil
                cursor += 1
            case Byte.minus, Byte.zero ... Byte.nine:
                guard case let .complete(number, end) = readNumber(at: cursor, final: final) else { return output }
                cursor = end
                if let key = pendingKey {
                    pendingKey = nil
                    output += assign(.number(number), to: key)
                }
                lastString = nil
            default:
                // Commas, opening brackets, true/false/null and stray prose end whatever key was waiting.
                pendingKey = nil
                lastString = nil
                cursor += 1
            }
        }
        return output
    }

    private func readString(at start: Int, final: Bool) -> Scan<String> {
        var index = start + 1
        var content: [UInt8] = []
        while index < bytes.count {
            switch bytes[index] {
            case Byte.backslash:
                guard let (decoded, length) = readEscape(at: index, final: final) else { return .incomplete }
                content += decoded
                index += length
            case Byte.quote:
                // A quote closes the string only when JSON structure follows. Anything else means the model left a
                // quote inside the text unescaped, so it is kept.
                switch nextSignificantByte(after: index) {
                case nil where !final:
                    return .incomplete
                case nil, Byte.colon, Byte.comma, Byte.closeBrace, Byte.closeBracket:
                    return .complete(UTF8Text.decode(content), end: index + 1)
                default:
                    content.append(Byte.quote)
                    index += 1
                }
            case let byte:
                content.append(byte)
                index += 1
            }
        }
        return .incomplete
    }

    /// Decodes the escape at `index` (a backslash). Returns the UTF-8 it stands for and how many bytes it used, or
    /// nil when the stream has not delivered all of it yet.
    private func readEscape(at index: Int, final: Bool) -> ([UInt8], Int)? {
        guard index + 1 < bytes.count else { return nil }
        let escaped = bytes[index + 1]
        switch escaped {
        case UInt8(ascii: "n"): return ([Byte.newline], 2)
        case UInt8(ascii: "t"): return ([Byte.tab], 2)
        case UInt8(ascii: "r"): return ([Byte.carriageReturn], 2)
        case UInt8(ascii: "b"): return ([0x08], 2)
        case UInt8(ascii: "f"): return ([0x0C], 2)
        case UInt8(ascii: "u"): return readUnicodeEscape(at: index, final: final)
        default: return ([escaped], 2) // \" \\ \/ and unknown escapes keep the character
        }
    }

    private func readUnicodeEscape(at index: Int, final: Bool) -> ([UInt8], Int)? {
        guard index + 6 <= bytes.count else { return final ? ([], bytes.count - index) : nil }
        guard let unit = hexValue(at: index + 2) else { return (Array("\\u".utf8), 2) }
        let replacement = Array("\u{FFFD}".utf8)
        switch unit {
        case 0xD800 ... 0xDBFF:
            guard index + 12 <= bytes.count else { return final ? (replacement, 6) : nil }
            guard bytes[index + 6] == Byte.backslash, bytes[index + 7] == UInt8(ascii: "u"),
                  let low = hexValue(at: index + 8), (0xDC00 ... 0xDFFF).contains(low),
                  let scalar = Unicode.Scalar(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00))
            else {
                return (replacement, 6)
            }
            return (Array(String(Character(scalar)).utf8), 12)
        case 0xDC00 ... 0xDFFF:
            return (replacement, 6)
        default:
            guard let scalar = Unicode.Scalar(unit) else { return (replacement, 6) }
            return (Array(String(Character(scalar)).utf8), 6)
        }
    }

    private func hexValue(at index: Int) -> UInt32? {
        guard index + 4 <= bytes.count else { return nil }
        return UInt32(UTF8Text.decode(bytes[index ..< index + 4]), radix: 16)
    }

    private func readNumber(at start: Int, final: Bool) -> Scan<String> {
        var index = start
        while index < bytes.count, Byte.numberCharacters.contains(bytes[index]) {
            index += 1
        }
        guard index < bytes.count || final else { return .incomplete }
        return .complete(UTF8Text.decode(bytes[start ..< index]), end: index)
    }

    private func nextSignificantByte(after index: Int) -> UInt8? {
        var next = index + 1
        while next < bytes.count, Byte.whitespace.contains(bytes[next]) {
            next += 1
        }
        return next < bytes.count ? bytes[next] : nil
    }

    // MARK: - Records

    private mutating func assign(_ value: Value, to key: String) -> [Segment] {
        switch key.lowercased().filter({ $0.isLetter || $0.isNumber }) {
        case "id", "segmentid", "segment":
            // A second id in the same record means the previous record ended without a closing brace.
            let previous = record.id == nil ? [] : flush()
            record.id = value.integer
            return previous + emitIfReady()
        case "translation", "translated", "translatedtext", "translationtext", "target", "targettext", "output":
            record.translation = value.text
            return emitIfReady()
        case "text":
            record.echoedText = value.text
            return []
        case "source", "sourcetext", "original", "originaltext":
            record.source = value.text
            return emitIfReady()
        default:
            guard case let .string(text) = value, let id = Int(key.trimmingCharacters(in: .whitespaces)) else { return [] }
            foundAny = true
            return [Segment(id: id, translation: text, source: nil)]
        }
    }

    private mutating func emitIfReady() -> [Segment] {
        guard let id = record.id, let translation = record.translation else { return [] }
        if let emitted = record.emitted, emitted.translation == translation, emitted.source == record.source {
            return []
        }
        record.emitted = (translation, record.source)
        foundAny = true
        return [Segment(id: id, translation: translation, source: record.source)]
    }

    /// Ends the current record. A record that only echoed `text` (the input's key) is taken as its translation.
    private mutating func flush() -> [Segment] {
        defer { record = Record() }
        if record.translation == nil, let echoed = record.echoedText {
            record.translation = echoed
        }
        if record.id == nil, let translation = record.translation {
            orphans.append(translation)
            return []
        }
        return emitIfReady()
    }

    // MARK: - Fallbacks

    private func bareStringArray() -> [String]? {
        guard let first = bytes.firstIndex(of: Byte.openBracket), let last = bytes.lastIndex(of: Byte.closeBracket), first < last
        else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: Data(bytes[first ... last]))) as? [String]
    }

    private static func positional(_ translations: [String], _ ids: [Int]) -> [Segment] {
        zip(ids, translations).map { Segment(id: $0, translation: $1, source: nil) }
    }

    private static func strippingCodeFences(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The ASCII bytes the parser looks for. Multi-byte UTF-8 sequences never contain them, so scanning bytes is safe.
private enum Byte {
    static let quote = UInt8(ascii: "\"")
    static let backslash = UInt8(ascii: "\\")
    static let colon = UInt8(ascii: ":")
    static let comma = UInt8(ascii: ",")
    static let openBrace = UInt8(ascii: "{")
    static let closeBrace = UInt8(ascii: "}")
    static let openBracket = UInt8(ascii: "[")
    static let closeBracket = UInt8(ascii: "]")
    static let minus = UInt8(ascii: "-")
    static let zero = UInt8(ascii: "0")
    static let nine = UInt8(ascii: "9")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let whitespace: Set<UInt8> = [space, tab, newline, carriageReturn]
    static let numberCharacters = Set("+-.0123456789eE".utf8)
}
