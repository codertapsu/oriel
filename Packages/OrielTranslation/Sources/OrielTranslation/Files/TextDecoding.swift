import CoreFoundation
import Foundation

/// Turns a text file's bytes into a string without asking which encoding it is in: UTF-16 with a byte-order mark,
/// UTF-8 (with or without one), the charset an HTML file declares, else Windows Latin 1, which spreadsheets and older
/// editors still write.
enum TextDecoding {
    static func string(from data: Data, declaredCharset: String? = nil) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let charset = declaredCharset, let encoding = encoding(named: charset), let text = String(data: data, encoding: encoding) {
            return text
        }
        return String(data: data, encoding: .windowsCP1252) ?? UTF8Text.decode(data)
    }

    /// The `charset` an HTML file declares in its first few kilobytes (`<meta charset="shift_jis">`).
    static func declaredHTMLCharset(in data: Data) -> String? {
        let head = UTF8Text.decode(data.prefix(4096)).lowercased()
        guard let range = head.range(of: "charset=") else { return nil }
        let value = head[range.upperBound...].drop { $0 == "\"" || $0 == "'" || $0 == " " }
        let name = value.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return name.isEmpty ? nil : String(name)
    }

    private static func encoding(named name: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}
