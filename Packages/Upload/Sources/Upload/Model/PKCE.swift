import CryptoKit
import Foundation
import Security

/// Proof Key for Code Exchange (RFC 7636): the app keeps a random verifier and sends only its SHA-256, so a stolen
/// authorization code is useless without it. Desktop apps cannot keep a client secret, and PKCE replaces it.
public nonisolated struct PKCE: Sendable, Equatable {
    /// 43 characters of base64url: 32 random bytes, the length RFC 7636 recommends.
    public let verifier: String

    /// The only method Oriel uses; RFC 7636 calls `plain` a fallback for clients that cannot hash.
    public static let method = "S256"

    public init(verifier: String) {
        self.verifier = verifier
    }

    /// A fresh verifier from the system's secure random generator.
    public static func generate() -> PKCE {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0 ..< 32).map { _ in UInt8.random(in: .min ... .max) }
        }
        return PKCE(verifier: base64URL(Data(bytes)))
    }

    /// `BASE64URL(SHA256(ASCII(verifier)))`, the `code_challenge`.
    public var challenge: String {
        Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Base64 with the URL-safe alphabet and no padding (RFC 7636 appendix A).
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
