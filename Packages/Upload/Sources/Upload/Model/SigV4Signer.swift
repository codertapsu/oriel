import CryptoKit
import Foundation

/// AWS Signature Version 4 for S3-compatible services (AWS, MinIO, Cloudflare R2, Backblaze B2). Pure, so it
/// is tested against AWS's published examples.
public nonisolated struct SigV4Signer: Sendable {
    public let accessKey: String
    public let secretKey: String
    public let region: String
    public let service: String

    public init(accessKey: String, secretKey: String, region: String, service: String = "s3") {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.service = service
    }

    /// The SHA-256 of an empty body, which S3 also accepts for GET and DELETE.
    public static let emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    /// Signs `request` in place: adds `x-amz-date`, `x-amz-content-sha256` and `Authorization`. The request
    /// must already carry every other header that should be signed (Host is taken from the URL).
    public func sign(_ request: inout URLRequest, payloadHash: String, date: Date = Date()) {
        let timestamp = Self.timestamp(date)
        request.setValue(timestamp, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        let parts = signatureParts(for: request, payloadHash: payloadHash, timestamp: timestamp)
        let credential = "\(accessKey)/\(parts.scope)"
        request.setValue(
            "AWS4-HMAC-SHA256 Credential=\(credential), SignedHeaders=\(parts.signedHeaders), Signature=\(parts.signature)",
            forHTTPHeaderField: "Authorization"
        )
    }

    /// The intermediate values, exposed for tests.
    public struct Parts: Sendable, Equatable {
        public let canonicalRequest: String
        public let stringToSign: String
        public let signedHeaders: String
        public let scope: String
        public let signature: String
    }

    public func signatureParts(for request: URLRequest, payloadHash: String, timestamp: String) -> Parts {
        let url = request.url ?? URL(fileURLWithPath: "/")
        var headers: [String: String] = [:]
        for (name, value) in request.allHTTPHeaderFields ?? [:] {
            headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
        }
        if let host = url.host {
            headers["host"] = url.port.map { "\(host):\($0)" } ?? host
        }
        headers["authorization"] = nil
        let names = headers.keys.sorted()
        let canonicalHeaders = names.map { "\($0):\(headers[$0] ?? "")\n" }.joined()
        let signedHeaders = names.joined(separator: ";")
        let canonicalRequest = [
            request.httpMethod ?? "GET",
            Self.canonicalPath(url),
            Self.canonicalQuery(url),
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")
        let day = String(timestamp.prefix(8))
        let scope = "\(day)/\(region)/\(service)/aws4_request"
        let stringToSign = ["AWS4-HMAC-SHA256", timestamp, scope, Self.hex(SHA256.hash(data: Data(canonicalRequest.utf8)))]
            .joined(separator: "\n")
        var key = SymmetricKey(data: Data("AWS4\(secretKey)".utf8))
        for component in [day, region, service, "aws4_request"] {
            key = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(component.utf8), using: key)))
        }
        let signature = Self.hex(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key))
        return Parts(
            canonicalRequest: canonicalRequest,
            stringToSign: stringToSign,
            signedHeaders: signedHeaders,
            scope: scope,
            signature: signature
        )
    }

    public static func payloadHash(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    /// Each path segment URI-encoded once, keeping the slashes (S3 does not double-encode).
    static func canonicalPath(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        guard !path.isEmpty else { return "/" }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .map { uriEncode(String($0)) }
            .joined(separator: "/")
    }

    static func canonicalQuery(_ url: URL) -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, !items.isEmpty else { return "" }
        let pairs: [(name: String, value: String)] = items.map { (uriEncode($0.name), uriEncode($0.value ?? "")) }
        let sorted = pairs.sorted { lhs, rhs in
            lhs.name == rhs.name ? lhs.value < rhs.value : lhs.name < rhs.name
        }
        return sorted.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }

    /// RFC 3986 unreserved characters stay, everything else is %XX (uppercase).
    static func uriEncode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.unicodeScalars.map { scalar in
            scalar.isASCII && allowed.contains(scalar)
                ? String(scalar)
                : String(scalar).utf8.map { String(format: "%%%02X", $0) }.joined()
        }.joined()
    }

    private static func hex(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
