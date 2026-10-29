import Darwin
import Foundation

/// Finds what Smart Redact hides in one line of recognized text (PLAN §17): keys and tokens (AWS, GitHub, Slack,
/// Stripe and Google keys, JWTs, PEM private-key headers, `password = …` values and other long random strings),
/// card numbers that pass the Luhn check, IBANs that pass mod 97, IPv4 and IPv6 addresses, email addresses, and,
/// through `NSDataDetector`, phone numbers and links. Pure and on-device; nothing it reads is logged.
nonisolated enum RedactionDetector {
    /// Every match in `text`. Where two overlap by more than half, the more specific category wins.
    static func matches(in text: String) -> [RedactionMatch] {
        let utf16 = text as NSString
        let whole = NSRange(location: 0, length: utf16.length)
        var found: [RedactionMatch] = []
        found += secrets(in: text, range: whole)
        found += cards(in: text, range: whole)
        found += ibans(in: text, range: whole)
        found += ipAddresses(in: text, range: whole)
        found += regexMatches(Patterns.email, in: text, range: whole, category: .email)
        found += detected(in: text, range: whole)
        return resolveOverlaps(found)
    }

    // MARK: - Categories

    private static func secrets(in text: String, range: NSRange) -> [RedactionMatch] {
        var found: [RedactionMatch] = []
        for pattern in Patterns.keys {
            found += regexMatches(pattern, in: text, range: range, category: .secret)
        }
        // `password: hunter2`: the value, however short, after a word that says it is secret.
        for match in Patterns.assignment.matches(in: text, range: range) where match.numberOfRanges > 1 {
            let value = match.range(at: 1)
            if value.location != NSNotFound, value.length > 0 {
                found.append(RedactionMatch(category: .secret, location: value.location, length: value.length))
            }
        }
        // Anything else long and random-looking.
        let string = text as NSString
        for token in tokens(in: text) where SecretHeuristics.looksLikeSecret(string.substring(with: token)) {
            found.append(RedactionMatch(category: .secret, location: token.location, length: token.length))
        }
        return found
    }

    private static func cards(in text: String, range: NSRange) -> [RedactionMatch] {
        let string = text as NSString
        return Patterns.card.matches(in: text, range: range).compactMap { match in
            ChecksumValidators.isCardNumber(string.substring(with: match.range))
                ? RedactionMatch(category: .cardNumber, location: match.range.location, length: match.range.length)
                : nil
        }
    }

    private static func ibans(in text: String, range: NSRange) -> [RedactionMatch] {
        let string = text as NSString
        return Patterns.iban.matches(in: text, range: range).compactMap { match in
            ChecksumValidators.isIBAN(string.substring(with: match.range))
                ? RedactionMatch(category: .iban, location: match.range.location, length: match.range.length)
                : nil
        }
    }

    private static func ipAddresses(in text: String, range: NSRange) -> [RedactionMatch] {
        let string = text as NSString
        var found: [RedactionMatch] = []
        let candidates = Patterns.ipv4.matches(in: text, range: range).map { ($0, AF_INET) }
            + Patterns.ipv6.matches(in: text, range: range).map { ($0, AF_INET6) }
        for (match, family) in candidates where isIPAddress(string.substring(with: match.range), family: family) {
            found.append(RedactionMatch(category: .ipAddress, location: match.range.location, length: match.range.length))
        }
        return found
    }

    /// Phone numbers and links, as the system's data detector finds them. Links to email addresses are left to the
    /// email pattern, and a phone number needs at least seven digits.
    private static func detected(in text: String, range: NSRange) -> [RedactionMatch] {
        guard let detector = Patterns.dataDetector else { return [] }
        let string = text as NSString
        return detector.matches(in: text, range: range).compactMap { result in
            switch result.resultType {
            case .phoneNumber:
                let digits = string.substring(with: result.range).filter(\.isNumber).count
                return (7 ... 15).contains(digits) ? RedactionMatch(
                    category: .phone,
                    location: result.range.location,
                    length: result.range.length
                ) : nil
            case .link:
                guard result.url?.scheme?.lowercased() != "mailto" else { return nil }
                return RedactionMatch(category: .link, location: result.range.location, length: result.range.length)
            default:
                return nil
            }
        }
    }

    // MARK: - Helpers

    private static func regexMatches(
        _ pattern: NSRegularExpression,
        in text: String,
        range: NSRange,
        category: RedactionCategory
    ) -> [RedactionMatch] {
        pattern.matches(in: text, range: range).map { RedactionMatch(
            category: category,
            location: $0.range.location,
            length: $0.range.length
        ) }
    }

    /// Runs of token characters (`SecretHeuristics.isTokenCharacter`), as UTF-16 ranges.
    static func tokens(in text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        var start: Int?
        var offset = 0
        for character in text {
            let width = character.utf16.count
            if SecretHeuristics.isTokenCharacter(character) {
                start = start ?? offset
            } else if let begin = start {
                ranges.append(NSRange(location: begin, length: offset - begin))
                start = nil
            }
            offset += width
        }
        if let begin = start {
            ranges.append(NSRange(location: begin, length: offset - begin))
        }
        return ranges
    }

    static func isIPAddress(_ text: String, family: Int32) -> Bool {
        var storage = in6_addr()
        return text.withCString { inet_pton(family, $0, &storage) } == 1
    }

    /// Keeps the most specific of overlapping matches, and one of identical ones.
    static func resolveOverlaps(_ matches: [RedactionMatch]) -> [RedactionMatch] {
        let ordered = matches.sorted { ($0.category.priority, $0.location, -$0.length) < ($1.category.priority, $1.location, -$1.length) }
        var kept: [RedactionMatch] = []
        for match in ordered {
            let covered = kept.contains { other in
                other.category.priority <= match.category.priority && match.overlap(with: other) > 0.5
            }
            if !covered {
                kept.append(match)
            }
        }
        return kept.sorted { ($0.location, $0.category.priority) < ($1.location, $1.category.priority) }
    }
}
