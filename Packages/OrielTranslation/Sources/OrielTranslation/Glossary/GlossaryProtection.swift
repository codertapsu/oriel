import Foundation

/// Applies a glossary for providers that have none of their own (Apple Translation, Google Basic, and DeepL for pairs
/// its glossaries do not cover): every term found in a segment is replaced with a numbered token (`[[1]]`) before
/// translating, and each token with the term's translation afterwards.
///
/// Translation engines usually carry such tokens through unchanged, the way they keep citation marks, but nothing
/// guarantees it. So a translation counts only when every token of its segment came back exactly once. Brackets and
/// digits may come back full-width (`［［１］］`), spaced or with one bracket pair lost; anything else, a token missing
/// or doubled, sends the original segment again without tokens, and that raw translation is used instead.
///
/// Limits: the engine translates around a token it cannot read, so grammar that depends on the term (articles,
/// gender, case endings, particles) may not agree with the substituted translation.
struct GlossaryProtection: Sendable {
    struct Token: Sendable, Equatable {
        let number: Int
        let term: GlossaryTerm
        /// The term as the segment spelled it ("Capture" at the start of a sentence), for the capitalization of the
        /// replacement.
        let original: String
    }

    /// What is sent instead of the segments: terms replaced by tokens.
    let segments: [TranslationSegment]
    private let originals: [Int: TranslationSegment]
    private let tokens: [Int: [Token]]

    init(segments: [TranslationSegment], terms: [GlossaryTerm]) {
        let usable = terms.filter(\.isUsable)
        var sent: [TranslationSegment] = []
        var originals: [Int: TranslationSegment] = [:]
        var tokens: [Int: [Token]] = [:]
        for segment in segments {
            originals[segment.id] = segment
            let matches = usable.isEmpty ? [] : GlossaryMatcher.matches(usable, in: segment.text)
            guard !matches.isEmpty else {
                sent.append(segment)
                continue
            }
            var text = ""
            var cursor = segment.text.startIndex
            var number = 0
            var segmentTokens: [Token] = []
            for match in matches {
                text += segment.text[cursor ..< match.range.lowerBound]
                number = Self.nextFreeNumber(after: number, in: segment.text)
                text += Self.token(number)
                segmentTokens.append(Token(number: number, term: match.term, original: String(segment.text[match.range])))
                cursor = match.range.upperBound
            }
            text += segment.text[cursor...]
            sent.append(TranslationSegment(id: segment.id, text: text))
            tokens[segment.id] = segmentTokens
        }
        self.segments = sent
        self.originals = originals
        self.tokens = tokens
    }

    /// Whether any segment contains a term.
    var protectsAnything: Bool {
        !tokens.isEmpty
    }

    func original(_ id: Int) -> TranslationSegment? {
        originals[id]
    }

    static func token(_ number: Int) -> String {
        "[[\(number)]]"
    }

    /// The translation with every token replaced by its term's translation; nil when a token did not come back
    /// exactly once. Segments without terms come back unchanged.
    func restore(_ segment: TranslatedSegment) -> TranslatedSegment? {
        guard let expected = tokens[segment.id] else { return segment }
        let byNumber = Dictionary(expected.map { ($0.number, $0) }) { first, _ in first }
        let found = Self.tokens(in: segment.text).filter { byNumber[$0.number] != nil }
        var counts: [Int: Int] = [:]
        for token in found {
            counts[token.number, default: 0] += 1
        }
        guard expected.allSatisfy({ counts[$0.number] == 1 }) else { return nil }
        var text = ""
        var cursor = segment.text.startIndex
        for token in found {
            guard let replacement = byNumber[token.number] else { continue }
            text += segment.text[cursor ..< token.range.lowerBound]
            text += Self.replacement(for: replacement)
            cursor = token.range.upperBound
        }
        text += segment.text[cursor...]
        return TranslatedSegment(id: segment.id, text: text, source: segment.source)
    }

    /// The term's translation, capitalized like the text it replaced when the term ignores case: a sentence-initial
    /// "Capture" becomes "Captura" for "capture" → "captura", and "CAPTURE" becomes "CAPTURA".
    static func replacement(for token: Token) -> String {
        let target = token.term.trimmedTarget
        guard !token.term.isCaseSensitive else { return target }
        let original = token.original
        let source = token.term.trimmedSource
        let isShouted = original.count > 1 && original == original.uppercased() && original != original.lowercased()
        if isShouted, source != source.uppercased() {
            return target.uppercased()
        }
        let capitalized = original.first?.isUppercase == true && source.first?.isUppercase == false
        if capitalized, let targetFirst = target.first, targetFirst.isLowercase {
            return targetFirst.uppercased() + target.dropFirst()
        }
        return target
    }

    /// The next number whose token cannot be confused with the segment's own text: neither `[N]` nor `[[N]]` occurs
    /// in it (a citation "[1]", say).
    private static func nextFreeNumber(after number: Int, in text: String) -> Int {
        var candidate = number + 1
        while text.contains("[\(candidate)]") {
            candidate += 1
        }
        return candidate
    }

    // MARK: - Finding tokens

    struct FoundToken: Equatable {
        let range: Range<String.Index>
        let number: Int
    }

    /// Every token-shaped run: one or two opening brackets (ASCII or full-width), optional spaces, digits in any
    /// script, optional spaces and one or two closing brackets.
    static func tokens(in text: String) -> [FoundToken] {
        var found: [FoundToken] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard isOpening(text[index]), let token = token(startingAt: index, in: text) else {
                index = text.index(after: index)
                continue
            }
            found.append(token)
            index = token.range.upperBound
        }
        return found
    }

    private static func token(startingAt start: String.Index, in text: String) -> FoundToken? {
        var index = text.index(after: start)
        if index < text.endIndex, isOpening(text[index]) {
            index = text.index(after: index)
        }
        index = skippingSpaces(from: index, in: text)
        var number = 0
        var digits = 0
        while index < text.endIndex, let digit = digitValue(text[index]) {
            number = number * 10 + digit
            digits += 1
            index = text.index(after: index)
            guard digits <= 6 else { return nil }
        }
        guard digits > 0 else { return nil }
        index = skippingSpaces(from: index, in: text)
        guard index < text.endIndex, isClosing(text[index]) else { return nil }
        index = text.index(after: index)
        if index < text.endIndex, isClosing(text[index]) {
            index = text.index(after: index)
        }
        return FoundToken(range: start ..< index, number: number)
    }

    private static func skippingSpaces(from index: String.Index, in text: String) -> String.Index {
        var index = index
        while index < text.endIndex, text[index].isWhitespace, !text[index].isNewline {
            index = text.index(after: index)
        }
        return index
    }

    private static func isOpening(_ character: Character) -> Bool {
        character == "[" || character == "［"
    }

    private static func isClosing(_ character: Character) -> Bool {
        character == "]" || character == "］"
    }

    /// The value of a decimal digit in any script (ASCII, full-width, Arabic-Indic, Devanagari…).
    private static func digitValue(_ character: Character) -> Int? {
        guard character.isWholeNumber, let value = character.wholeNumberValue, (0 ... 9).contains(value) else { return nil }
        return value
    }
}

extension GlossaryProtection {
    /// Runs `translate` on `segments` with `terms` protected and hands each result to `emit`. Segments whose tokens
    /// did not survive go through `translate` once more, unprotected, and that raw translation is emitted instead.
    /// Without any term in the text this is just `translate(segments, emit)`.
    static func run(
        _ segments: [TranslationSegment],
        terms: [GlossaryTerm],
        emit: @escaping (TranslatedSegment) -> Void,
        translate: ([TranslationSegment], (TranslatedSegment) -> Void) async throws -> Void
    ) async throws {
        let protection = GlossaryProtection(segments: segments, terms: terms)
        guard protection.protectsAnything else {
            try await translate(segments, emit)
            return
        }
        var lost: [TranslationSegment] = []
        try await translate(protection.segments) { translated in
            if let restored = protection.restore(translated) {
                emit(restored)
            } else if let original = protection.original(translated.id) {
                lost.append(original)
            }
        }
        if !lost.isEmpty {
            try await translate(lost, emit)
        }
    }
}
