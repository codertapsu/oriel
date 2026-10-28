import Foundation
@testable import OrielTranslation
import Security

/// Google service account key files whose RSA keys are made during the test, so no private key is ever checked in.
enum TestServiceAccount {
    struct Made {
        let json: String
        let publicKey: SecKey
        let pkcs8PEM: String
        let pkcs1PEM: String
    }

    struct KeyError: Error {}

    /// A JWT taken apart: its header and claims as objects, and what was signed with what signature.
    struct JWTParts {
        let header: [String: Any]
        let claims: [String: Any]
        let signingInput: Data
        let signature: Data
    }

    static func make(
        tokenURL: String,
        email: String = "oriel@test-project.iam.gserviceaccount.com",
        project: String = "test-project"
    ) throws -> Made {
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, nil),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let pkcs1 = SecKeyCopyExternalRepresentation(privateKey, nil) as Data?
        else {
            throw KeyError()
        }
        let algorithm = PrivateKeyPEM.rsaEncryptionOID + [0x05, 0x00]
        let pkcs8 = Data(der(0x30, der(0x02, [0x00]) + der(0x30, algorithm) + der(0x04, Array(pkcs1))))
        let pkcs8PEM = pem("PRIVATE KEY", pkcs8)
        let json = TestSupport.json([
            "type": "service_account",
            "project_id": project,
            "private_key_id": "0123abcd",
            "private_key": pkcs8PEM,
            "client_email": email,
            "token_uri": tokenURL,
        ])
        return Made(json: json, publicKey: publicKey, pkcs8PEM: pkcs8PEM, pkcs1PEM: pem("RSA PRIVATE KEY", pkcs1))
    }

    static func pem(_ label: String, _ der: Data) -> String {
        let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN \(label)-----\n\(base64)\n-----END \(label)-----\n"
    }

    /// One DER tag-length-value.
    static func der(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        guard content.count >= 0x80 else { return [tag, UInt8(content.count)] + content }
        var length = content.count
        var lengthBytes: [UInt8] = []
        while length > 0 {
            lengthBytes.insert(UInt8(length & 0xFF), at: 0)
            length >>= 8
        }
        return [tag, 0x80 | UInt8(lengthBytes.count)] + lengthBytes + content
    }

    static func decode(jwt: String) throws -> JWTParts {
        let parts = jwt.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let header = try JSONSerialization.jsonObject(with: base64URLDecode(parts[0])) as? [String: Any],
              let claims = try JSONSerialization.jsonObject(with: base64URLDecode(parts[1])) as? [String: Any]
        else {
            throw KeyError()
        }
        return try JWTParts(
            header: header,
            claims: claims,
            signingInput: Data("\(parts[0]).\(parts[1])".utf8),
            signature: base64URLDecode(parts[2])
        )
    }

    private static func base64URLDecode(_ text: String) throws -> Data {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { throw KeyError() }
        return data
    }
}
