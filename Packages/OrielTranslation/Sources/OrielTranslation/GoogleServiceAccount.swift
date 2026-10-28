import Foundation
import Security

/// A Google Cloud service account key: the JSON file the Cloud console downloads (PLAN §7.7.2). Cloud Translation
/// Advanced (v3), which glossaries need, takes OAuth tokens and no API keys, so Oriel signs its own token requests
/// with this key. The file is kept in the Keychain beside the provider's API key; descriptions of this value are
/// redacted, so the private key never reaches a log.
struct GoogleServiceAccount: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    static let defaultTokenURL = "https://oauth2.googleapis.com/token"

    /// The account's address, which signs the token requests (`…@….iam.gserviceaccount.com`).
    let clientEmail: String
    /// The Cloud project the account belongs to: a glossary given by ID alone is looked for there.
    let projectID: String
    let tokenURL: URL
    /// The key file as imported, which is what the Keychain stores.
    let json: String
    private let privateKey: String

    /// Reads and checks a key file; the error says what is wrong with it.
    init(json: String) throws {
        guard let data = json.data(using: .utf8), let file = try? JSONDecoder().decode(KeyFile.self, from: data) else {
            throw TranslationFailure.notConfigured("That isn't a service account key file (JSON from the Google Cloud console).")
        }
        guard file.type == "service_account" else {
            throw TranslationFailure.notConfigured("That key file is for “\(file.type ?? "nothing")”, not a service account.")
        }
        guard let email = file.clientEmail?.trimmingCharacters(in: .whitespaces), !email.isEmpty,
              let key = file.privateKey, !key.isEmpty
        else {
            throw TranslationFailure.notConfigured("The key file has no client_email or private_key.")
        }
        guard let tokenURL = URL(string: file.tokenURI ?? Self.defaultTokenURL), tokenURL.scheme?.lowercased() == "https" else {
            throw TranslationFailure.notConfigured("The key file's token_uri isn't an https:// address.")
        }
        _ = try PrivateKeyPEM.rsaKey(from: key)
        clientEmail = email
        projectID = file.projectID?.trimmingCharacters(in: .whitespaces) ?? ""
        self.tokenURL = tokenURL
        self.json = json
        privateKey = key
    }

    /// An RS256 (RSASSA-PKCS1-v1_5 with SHA-256) signature of `data` with the account's key.
    func sign(_ data: Data) throws -> Data {
        let key = try PrivateKeyPEM.rsaKey(from: privateKey)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, &error) as Data? else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw TranslationFailure.notConfigured("Signing with the service account key failed: \(reason)")
        }
        return signature
    }

    var description: String {
        "<service account>"
    }

    var debugDescription: String {
        "<service account>"
    }

    var customMirror: Mirror {
        Mirror(self, children: [])
    }
}

/// The fields of a key file Oriel uses.
private struct KeyFile: Decodable {
    let type: String?
    let projectID: String?
    let privateKey: String?
    let clientEmail: String?
    let tokenURI: String?

    enum CodingKeys: String, CodingKey {
        case type
        case projectID = "project_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case tokenURI = "token_uri"
    }
}
