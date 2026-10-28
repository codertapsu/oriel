import Foundation
import OrielCore

/// Uploads one object with a signed PUT and returns its public link (PLAN §7.8).
public struct S3Uploader: Sendable {
    public let configuration: UploadConfiguration
    public let secretKey: String
    private let session: URLSession

    public init(configuration: UploadConfiguration, secretKey: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.secretKey = secretKey
        self.session = session
    }

    public enum UploadError: LocalizedError, Sendable, Equatable {
        case notConfigured
        case badURL
        case rejected(status: Int, message: String)

        public var errorDescription: String? {
            switch self {
            case .notConfigured: "Uploads are not set up yet. Fill in Settings → Upload."
            case .badURL: "The upload endpoint is not a valid URL."
            case let .rejected(status, message): "The server refused the upload (HTTP \(status)). \(message)"
            }
        }
    }

    /// PUTs `data` under `key` and returns the link to share.
    @discardableResult
    public func upload(_ data: Data, key: String, contentType: String) async throws -> URL {
        guard configuration.isComplete, !secretKey.isEmpty else { throw UploadError.notConfigured }
        guard let url = configuration.objectURL(key: key), let link = configuration.publicURL(key: key) else {
            throw UploadError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        signer.sign(&request, payloadHash: SigV4Signer.payloadHash(data))
        let (body, response) = try await session.upload(for: request, from: data)
        try check(response, body: body)
        return link
    }

    /// Deletes `key`; used by "Test connection" to clean up after itself.
    public func delete(key: String) async throws {
        guard let url = configuration.objectURL(key: key) else { throw UploadError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        signer.sign(&request, payloadHash: SigV4Signer.emptyPayloadHash)
        let (body, response) = try await session.data(for: request)
        try check(response, body: body)
    }

    private var signer: SigV4Signer {
        SigV4Signer(accessKey: configuration.accessKey, secretKey: secretKey, region: configuration.region)
    }

    private func check(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            // S3 errors are XML; the <Message> is the useful part.
            let text = String(data: body, encoding: .utf8) ?? ""
            let message = text.range(of: "<Message>").flatMap { start in
                text.range(of: "</Message>").map { String(text[start.upperBound ..< $0.lowerBound]) }
            } ?? ""
            throw UploadError.rejected(status: http.statusCode, message: message)
        }
    }
}
