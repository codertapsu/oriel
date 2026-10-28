import Foundation

/// Where uploads go (PLAN §7.8). The secret key is not here: it lives in the Keychain.
public struct UploadConfiguration: Codable, Sendable, Equatable {
    /// e.g. `https://s3.eu-central-1.amazonaws.com`, `https://minio.internal`, `https://<account>.r2.cloudflarestorage.com`.
    public var endpoint: String
    /// `auto` for R2; any region name for MinIO.
    public var region: String
    public var bucket: String
    public var accessKey: String
    /// Folder inside the bucket, without slashes at either end.
    public var pathPrefix: String
    /// Where uploaded objects are served from, e.g. `https://files.internal/oriel`. Empty: the endpoint URL.
    public var publicBaseURL: String
    /// `https://host/bucket/key` instead of `https://bucket.host/key`; MinIO and most self-hosted servers need it.
    public var usesPathStyle: Bool
    /// Re-encode images before upload so no metadata leaves the Mac.
    public var stripsMetadata: Bool

    public init(
        endpoint: String = "",
        region: String = "us-east-1",
        bucket: String = "",
        accessKey: String = "",
        pathPrefix: String = "",
        publicBaseURL: String = "",
        usesPathStyle: Bool = true,
        stripsMetadata: Bool = true
    ) {
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKey = accessKey
        self.pathPrefix = pathPrefix
        self.publicBaseURL = publicBaseURL
        self.usesPathStyle = usesPathStyle
        self.stripsMetadata = stripsMetadata
    }

    public var isComplete: Bool {
        URL(string: endpoint)?.host != nil && !bucket.isEmpty && !accessKey.isEmpty
    }

    /// The URL to PUT an object to.
    public func objectURL(key: String) -> URL? {
        guard var components = URLComponents(string: endpoint) else { return nil }
        let encodedKey = key.split(separator: "/").map { SigV4Signer.uriEncode(String($0)) }.joined(separator: "/")
        if usesPathStyle {
            components.percentEncodedPath = "/\(bucket)/\(encodedKey)"
        } else {
            components.host = "\(bucket).\(components.host ?? "")"
            components.percentEncodedPath = "/\(encodedKey)"
        }
        return components.url
    }

    /// The link to share for an object.
    public func publicURL(key: String) -> URL? {
        guard !publicBaseURL.isEmpty else { return objectURL(key: key) }
        let encodedKey = key.split(separator: "/").map { SigV4Signer.uriEncode(String($0)) }.joined(separator: "/")
        let base = publicBaseURL.hasSuffix("/") ? String(publicBaseURL.dropLast()) : publicBaseURL
        return URL(string: "\(base)/\(encodedKey)")
    }

    /// An object key nobody can guess (PLAN §8.4): the prefix, 128 random bits, then the file name.
    public func makeKey(fileName: String) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        let prefix = pathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return [prefix, token, fileName].filter { !$0.isEmpty }.joined(separator: "/")
    }
}
