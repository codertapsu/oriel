import Foundation
import Security

/// Reads an RSA private key from PEM text: PKCS #8 (`BEGIN PRIVATE KEY`, what Google's key files hold) or PKCS #1
/// (`BEGIN RSA PRIVATE KEY`). Security framework takes PKCS #1 only, so a PKCS #8 wrapper is taken off first. The key
/// is made in memory and never added to the Keychain.
enum PrivateKeyPEM {
    /// `1.2.840.113549.1.1.1`, rsaEncryption, as a DER object identifier.
    static let rsaEncryptionOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]

    static func rsaKey(from pem: String) throws -> SecKey {
        guard let (label, der) = decode(pem) else {
            throw TranslationFailure.notConfigured("The key file's private key isn't PEM text.")
        }
        let pkcs1: Data
        switch label {
        case "PRIVATE KEY":
            guard let unwrapped = pkcs1Key(fromPKCS8: der) else {
                throw TranslationFailure.notConfigured("The key file's private key isn't an RSA key.")
            }
            pkcs1 = unwrapped
        case "RSA PRIVATE KEY":
            pkcs1 = der
        default:
            throw TranslationFailure.notConfigured("The key file holds a \(label), not a private key.")
        }
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(pkcs1 as CFData, attributes as CFDictionary, &error) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw TranslationFailure.notConfigured("The key file's private key can't be read: \(reason)")
        }
        return key
    }

    /// The label (`PRIVATE KEY`) and the DER bytes of the first PEM block in `pem`.
    static func decode(_ pem: String) -> (label: String, der: Data)? {
        let lines = pem.replacingOccurrences(of: "\r", with: "").split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let begin = lines.firstIndex(where: { $0.hasPrefix("-----BEGIN ") && $0.hasSuffix("-----") }) else { return nil }
        let label = String(lines[begin].dropFirst("-----BEGIN ".count).dropLast("-----".count))
        guard let end = lines[begin...].firstIndex(of: "-----END \(label)-----"), end > begin + 1,
              let der = Data(base64Encoded: lines[(begin + 1) ..< end].joined())
        else {
            return nil
        }
        return (label, der)
    }

    /// The PKCS #1 `RSAPrivateKey` inside a PKCS #8 `PrivateKeyInfo` (RFC 5208): SEQUENCE { INTEGER version,
    /// SEQUENCE { rsaEncryption, NULL }, OCTET STRING key, … }. Nil for anything else.
    static func pkcs1Key(fromPKCS8 der: Data) -> Data? {
        var outer = DERReader(der)
        guard let info = outer.read(tag: 0x30) else { return nil }
        var reader = DERReader(info)
        guard reader.read(tag: 0x02) != nil,
              let algorithm = reader.read(tag: 0x30), algorithm.starts(with: rsaEncryptionOID),
              let key = reader.read(tag: 0x04), !key.isEmpty
        else {
            return nil
        }
        return key
    }
}

/// Reads DER one tag-length-value at a time; enough for the few structures `PrivateKeyPEM` looks into.
private struct DERReader {
    private let bytes: [UInt8]
    private var index = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    /// The contents of the next value when its tag is `tag`, else nil.
    mutating func read(tag: UInt8) -> Data? {
        guard index < bytes.count, bytes[index] == tag else { return nil }
        index += 1
        guard let length = readLength(), length <= bytes.count - index else { return nil }
        defer { index += length }
        return Data(bytes[index ..< index + length])
    }

    /// Short form (one byte below 0x80) or long form (0x8n, then n bytes, big-endian).
    private mutating func readLength() -> Int? {
        guard index < bytes.count else { return nil }
        let first = bytes[index]
        index += 1
        guard first & 0x80 != 0 else { return Int(first) }
        let count = Int(first & 0x7F)
        guard (1 ... 4).contains(count), count <= bytes.count - index else { return nil }
        var length = 0
        for _ in 0 ..< count {
            length = length << 8 | Int(bytes[index])
            index += 1
        }
        return length
    }
}
