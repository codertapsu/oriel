import Foundation

/// Telling a generic secret (an API key, a token, a password hash) from ordinary text: long, made of the characters
/// keys are made of, and random-looking. Random strings switch between upper case, lower case and digits far more
/// often than words and identifiers do, and use many different characters, so both are measured. Pure.
nonisolated enum SecretHeuristics {
    /// Shorter strings are too often ordinary words, version numbers or short hashes.
    static let minimumLength = 20
    /// Hex strings are secrets from 32 characters (MD5-sized and up); shorter ones are commit hashes and colours.
    static let minimumHexLength = 32
    /// Below this share of character-class changes, a string reads like words in camel case.
    static let minimumClassChangeRatio = 0.38
    /// Bits of Shannon entropy per character below which a string is too repetitive to be random.
    static let minimumEntropy = 3.5

    /// The characters keys and tokens are made of (base64, base64url, hex).
    static func isTokenCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || "+/=_-".contains(character))
    }

    static func looksLikeSecret(_ token: String) -> Bool {
        let length = token.count
        guard length >= minimumLength, length <= 1024, token.allSatisfy(isTokenCharacter), !isUUID(token),
              !isPath(token) else { return false }
        let letters = token.filter(\.isLetter).count
        let digits = token.filter(\.isNumber).count
        guard letters > 0, digits > 0 else { return false }
        if token.allSatisfy(\.isHexDigit) {
            return length >= minimumHexLength && entropy(of: token) >= 3.0
        }
        let hasLower = token.contains(where: \.isLowercase)
        let hasUpper = token.contains(where: \.isUppercase)
        guard hasLower || hasUpper else { return false }
        return classChangeRatio(token) >= minimumClassChangeRatio && entropy(of: token) >= minimumEntropy
    }

    /// Shannon entropy of the string's own characters, in bits per character.
    static func entropy(of text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for character in text {
            counts[character, default: 0] += 1
        }
        let total = Double(text.count)
        return counts.values.reduce(0) { sum, count in
            let probability = Double(count) / total
            return sum - probability * log2(probability)
        }
    }

    /// How often consecutive characters change class (upper case, lower case, digit, symbol), 0…1.
    static func classChangeRatio(_ text: String) -> Double {
        func characterClass(_ character: Character) -> Int {
            if character.isUppercase {
                return 0
            }
            if character.isLowercase {
                return 1
            }
            if character.isNumber {
                return 2
            }
            return 3
        }
        let classes = text.map(characterClass)
        guard classes.count > 1 else { return 0 }
        let changes = zip(classes, classes.dropFirst()).count { $0 != $1 }
        return Double(changes) / Double(classes.count - 1)
    }

    /// A UUID (8-4-4-4-12 hex digits): an identifier, not a secret.
    static func isUUID(_ text: String) -> Bool {
        let groups = text.split(separator: "-", omittingEmptySubsequences: false)
        return groups.map(\.count) == [8, 4, 4, 4, 12] && groups.allSatisfy { $0.allSatisfy(\.isHexDigit) }
    }

    /// A path such as `Users/marcus/Library`: segments that are words.
    static func isPath(_ text: String) -> Bool {
        let segments = text.split(separator: "/")
        return segments.count >= 2 && segments.allSatisfy { segment in segment.allSatisfy { $0.isLetter || $0 == "_" || $0 == "-" } }
    }
}
