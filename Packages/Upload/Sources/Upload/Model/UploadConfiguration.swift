import Foundation

/// An S3-compatible bucket (PLAN §7.8): AWS, MinIO, Cloudflare R2, Backblaze B2. The secret key is not here: it lives
/// in the Keychain.
///
/// Also the type of the single destination Oriel 0.1 had (`UploadSettings.configuration`), which a bootstrap import
/// still writes and the destination list takes in (`UploadDestinationStore`).
public nonisolated struct UploadConfiguration: Codable, Sendable, Equatable {
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
    /// Re-encode images before upload so no metadata leaves the Mac. Since destinations have their own switch, this
    /// one is read only when the 0.1 destination is taken into the list.
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

    /// Missing fields take their defaults, so settings written by another version still load.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            endpoint: container.decodeIfPresent(String.self, forKey: .endpoint) ?? "",
            region: container.decodeIfPresent(String.self, forKey: .region) ?? "us-east-1",
            bucket: container.decodeIfPresent(String.self, forKey: .bucket) ?? "",
            accessKey: container.decodeIfPresent(String.self, forKey: .accessKey) ?? "",
            pathPrefix: container.decodeIfPresent(String.self, forKey: .pathPrefix) ?? "",
            publicBaseURL: container.decodeIfPresent(String.self, forKey: .publicBaseURL) ?? "",
            usesPathStyle: container.decodeIfPresent(Bool.self, forKey: .usesPathStyle) ?? true,
            stripsMetadata: container.decodeIfPresent(Bool.self, forKey: .stripsMetadata) ?? true
        )
    }

    public var isComplete: Bool {
        URL(string: endpoint)?.host != nil && !bucket.isEmpty && !accessKey.isEmpty
    }

    /// Whether anything was filled in, so an untouched 0.1 setting is not taken in as a destination.
    public var hasContent: Bool {
        ![endpoint, bucket, accessKey].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
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

    /// The object key for `path`, the destination's rendered name template: the folder in the bucket, then the path.
    public func key(for path: [String]) -> String {
        let prefix = pathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return ([prefix] + path).filter { !$0.isEmpty }.joined(separator: "/")
    }

    /// An object key nobody can guess (PLAN §8.4): the prefix, 128 random bits, then the file name. The name template
    /// `{random}/{name}` gives the same keys.
    public func makeKey(fileName: String) -> String {
        key(for: [UploadNameTemplate.randomToken(), fileName])
    }
}
