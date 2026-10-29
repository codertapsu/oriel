import Foundation

extension RedactionDetector {
    /// The expressions Smart Redact matches with, compiled once. `NSRegularExpression` and `NSDataDetector` are
    /// immutable and safe to use from any thread.
    nonisolated enum Patterns {
        /// Keys with a known shape: AWS access key IDs, GitHub tokens, Slack tokens, Stripe keys, Google API keys,
        /// JSON Web Tokens and PEM private-key headers.
        static let keys: [NSRegularExpression] = [
            #"\b(?:AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}\b"#,
            #"\bgh[poursa]_[A-Za-z0-9]{30,}\b"#,
            #"\bgithub_pat_[A-Za-z0-9_]{20,}"#,
            #"\bxox[abposr]-[A-Za-z0-9-]{10,}"#,
            #"\b(?:sk|pk|rk)_(?:live|test)_[A-Za-z0-9]{10,}\b"#,
            #"\bAIza[0-9A-Za-z_\-]{30,}"#,
            #"\beyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}"#,
            #"-{2,}\s*BEGIN [A-Z ]*PRIVATE KEY\s*-{2,}"#,
        ].compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

        /// `password = …`, `api_key: …`, `token=…`: the value is group 1.
        static let assignment = expression(
            #"\b(?:pass(?:word|wd)?|pwd|secret|token|api[_\- ]?key|access[_\- ]?key|private[_\- ]?key|client[_\- ]?secret)"#
                + #"\s*[:=]\s*["']?([^\s"',;]{4,})"#,
            options: [.caseInsensitive]
        )

        /// 13 to 19 digits, in groups separated by spaces or dashes or not at all.
        static let card = expression(#"(?<![\d-])(?:\d[ -]?){12,18}\d(?![\d])"#)

        /// Two letters, two check digits, then 11 to 30 letters and digits, in groups of four or not.
        static let iban = expression(#"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}\b"#)

        static let ipv4 = expression(#"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])"#)

        /// Candidates only; `inet_pton` decides.
        static let ipv6 = expression(#"(?<![:\w])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![:\w])"#)

        static let email = expression(
            #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
            options: [.caseInsensitive]
        )

        static let dataDetector: NSDataDetector? = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue
        )

        private static func expression(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression {
            do {
                return try NSRegularExpression(pattern: pattern, options: options)
            } catch {
                // The patterns are constants, so this only happens if one is mistyped; a test compiles every one.
                preconditionFailure("Invalid redaction pattern \(pattern): \(error)")
            }
        }
    }
}
