import CryptoKit
import Foundation
import OrielCore

/// Uploads one object with a signed PUT and returns its public link (PLAN §7.8).
public nonisolated struct S3Uploader: Sendable {
    public let configuration: UploadConfiguration
    public let secretKey: String
    private let session: URLSession

    public init(configuration: UploadConfiguration, secretKey: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.secretKey = secretKey
        self.session = session
    }

    /// PUTs `data` under `key` and returns the link to share.
    @discardableResult
    public func upload(_ data: Data, key: String, contentType: String) async throws -> URL {
        let (request, link) = try signedPut(
            key: key,
            contentType: contentType,
            length: Int64(data.count),
            payloadHash: SigV4Signer.payloadHash(data)
        )
        let (body, response) = try await UploadHTTP(session: session).upload(request, from: data, delegate: nil)
        try Self.check(response, body: body)
        return link
    }

    /// PUTs the file under `key`, streamed from disk, and returns the link to share.
    func upload(fileAt file: URL, key: String, contentType: String, length: Int64, delegate: UploadTaskDelegate?) async throws -> URL {
        let hash = try Self.payloadHash(of: file)
        let (request, link) = try signedPut(key: key, contentType: contentType, length: length, payloadHash: hash)
        let (body, response) = try await UploadHTTP(session: session).upload(request, fromFile: file, delegate: delegate)
        try Self.check(response, body: body)
        return link
    }

    /// Deletes `key`; used by "Test connection" to clean up after itself.
    public func delete(key: String) async throws {
        guard let url = configuration.objectURL(key: key) else { throw UploadError.invalidSettings("The endpoint is not a valid URL.") }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        signer.sign(&request, payloadHash: SigV4Signer.emptyPayloadHash)
        let (body, response) = try await UploadHTTP(session: session).send(request)
        try Self.check(response, body: body)
    }

    private func signedPut(key: String, contentType: String, length: Int64, payloadHash: String) throws -> (URLRequest, URL) {
        guard configuration.isComplete, !secretKey.isEmpty else {
            throw UploadError.invalidSettings("The bucket needs an endpoint, a bucket name, an access key and a secret key.")
        }
        guard let url = configuration.objectURL(key: key), let link = configuration.publicURL(key: key) else {
            throw UploadError.invalidSettings("The endpoint or the public base URL is not a valid URL.")
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        signer.sign(&request, payloadHash: payloadHash)
        return (request, link)
    }

    private var signer: SigV4Signer {
        SigV4Signer(accessKey: configuration.accessKey, secretKey: secretKey, region: configuration.region)
    }

    /// The SHA-256 SigV4 signs, read through the file a megabyte at a time.
    static func payloadHash(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// S3 errors are XML; `<Code>` says what went wrong and `<Message>` how.
    static func check(_ response: HTTPURLResponse, body: Data) throws {
        guard !(200 ..< 300).contains(response.statusCode) else { return }
        let text = body.utf8Text
        let code = element("Code", in: text)
        let message = element("Message", in: text)
        switch code {
        case "InvalidAccessKeyId", "SignatureDoesNotMatch":
            throw UploadError.unauthorized("The bucket refused the access key or the secret key.")
        case "AccessDenied":
            throw UploadError.forbidden("The access key may not write to this bucket.")
        case "NoSuchBucket":
            throw UploadError.notFound("The bucket doesn't exist at that endpoint.")
        case "RequestTimeTooSkewed":
            throw UploadError.failed("This Mac's clock is too far off for the bucket. Set the date and time automatically.")
        case "EntityTooLarge":
            throw UploadError.tooLarge("The file is larger than the bucket accepts in one upload (5 GB).")
        default:
            throw UploadError.server(status: response.statusCode, message: message)
        }
    }

    private static func element(_ name: String, in text: String) -> String {
        guard let start = text.range(of: "<\(name)>"),
              let end = text.range(of: "</\(name)>", range: start.upperBound ..< text.endIndex)
        else {
            return ""
        }
        return String(text[start.upperBound ..< end.lowerBound])
    }
}
