import Foundation

/// The `Dropbox-API-Arg` header, which carries a content endpoint's arguments as JSON. HTTP headers are ASCII, so
/// Dropbox asks for "HTTP header safe" JSON: every character from U+007F up escaped as `\uXXXX`, in UTF-16 (a pair of
/// escapes beyond U+FFFF). Keys are sorted so the header is the same every time.
nonisolated enum DropboxAPIArg {
    static func header(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try escapeNonASCII(encoder.encode(value).utf8Text)
    }

    /// `json` with U+007F and everything above it escaped.
    static func escapeNonASCII(_ json: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(json.utf8.count)
        for unit in json.utf16 {
            if unit < 0x7F {
                escaped.unicodeScalars.append(Unicode.Scalar(UInt8(unit)))
            } else {
                escaped += String(format: "\\u%04x", unit)
            }
        }
        return escaped
    }
}
