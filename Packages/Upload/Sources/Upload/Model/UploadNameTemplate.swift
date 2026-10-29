import Foundation
import Security

/// The uploaded file's name, from a destination's template, like the capture file name template (Settings →
/// Capture), with `/` making folders.
///
/// Tokens: `{name}` (the window's title, the file's name, or "Oriel"), `{date}` (2026-10-29), `{time}` (10.15.30)
/// and `{random}` (32 hex digits, 128 random bits: a link nobody can guess, PLAN §8.4). The template is split at `/`
/// before the tokens are filled, so a `/` in a window title never makes a folder. Characters that some service or
/// file system refuses (`\ / : * ? " < > |`, control characters) become `-`.
public nonisolated enum UploadNameTemplate {
    /// Each upload in a folder of its own with a random name, and the file keeps its name: Oriel 0.1's object keys.
    public static let unguessable = "{random}/{name}"
    /// For services whose links are unguessable anyway.
    public static let readable = "{name} {date} at {time}"
    public static let tokens = ["{name}", "{date}", "{time}", "{random}"]
    static let fallbackName = "Oriel"
    /// Names may have 255 bytes; this leaves room for the extension and a " 2".
    static let maxSegmentLength = 200

    /// What the tokens are filled from.
    public struct Context: Sendable {
        public var name: String
        public var date: Date
        public var random: String

        public init(name: String, date: Date = Date(), random: String = UploadNameTemplate.randomToken()) {
            self.name = name
            self.date = date
            self.random = random
        }
    }

    /// The path below the destination's folder, one element per folder and the file name last, with `fileExtension`.
    public static func render(_ template: String, context: Context, fileExtension: String, timeZone: TimeZone = .current) -> [String] {
        let values = values(for: context, timeZone: timeZone)
        var segments = template.split(separator: "/", omittingEmptySubsequences: true).map { part in
            var segment = String(part)
            for (token, value) in values {
                segment = segment.replacingOccurrences(of: token, with: value)
            }
            return sanitize(segment)
        }.filter { !$0.isEmpty }
        if segments.isEmpty {
            segments = [sanitize(context.name).isEmpty ? fallbackName : sanitize(context.name)]
        }
        let ending = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if !ending.isEmpty, let last = segments.popLast() {
            segments.append("\(last).\(ending)")
        }
        return segments
    }

    /// One path element made safe for every destination: separators and wildcards become `-`, line breaks and other
    /// control characters spaces, and runs of spaces one; no leading dot (a hidden file) and no trailing dot or space
    /// (SMB refuses those); at most `maxSegmentLength` characters. Empty when nothing is left.
    public static func sanitize(_ segment: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let blank = CharacterSet.controlCharacters.union(.newlines)
        let replaced = String(String.UnicodeScalarView(segment.unicodeScalars.map { scalar in
            unsafe.contains(scalar) ? "-" : blank.contains(scalar) ? " " : scalar
        }))
        var cleaned = replaced.split(separator: " ").joined(separator: " ")
        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        cleaned = String(cleaned.prefix(maxSegmentLength))
        while let last = cleaned.last, last == "." || last == " " {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    /// 128 random bits as 32 lowercase hex digits.
    public static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0 ..< 16).map { _ in UInt8.random(in: .min ... .max) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Whether every upload gets a name of its own, so none can replace another one with the same name.
    public static func namesAreUnique(_ template: String) -> Bool {
        template.contains("{random}") || template.contains("{time}")
    }

    /// Whether links made from it can be guessed by someone who knows another one.
    public static func isUnguessable(_ template: String) -> Bool {
        template.contains("{random}")
    }

    private static func values(for context: Context, timeZone: TimeZone) -> [String: String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: context.date)
        let name = context.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "{name}": name.isEmpty ? fallbackName : name,
            "{date}": "\(pad(parts.year, 4))-\(pad(parts.month, 2))-\(pad(parts.day, 2))",
            "{time}": "\(pad(parts.hour, 2)).\(pad(parts.minute, 2)).\(pad(parts.second, 2))",
            "{random}": context.random,
        ]
    }

    private static func pad(_ value: Int?, _ width: Int) -> String {
        let digits = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
