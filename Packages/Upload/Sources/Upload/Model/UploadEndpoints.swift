import Foundation

/// The addresses of the services Oriel signs in to and uploads to. Tests point every one at a stub server, so no
/// test reaches the network.
public nonisolated struct UploadEndpoints: Sendable, Equatable {
    public var dropboxAuthorize: String
    public var dropboxAPI: String
    public var dropboxContent: String
    public var googleAuthorize: String
    public var googleToken: String
    public var googleRevoke: String
    public var googleAPI: String

    public static let production = UploadEndpoints(
        dropboxAuthorize: "https://www.dropbox.com/oauth2/authorize",
        dropboxAPI: "https://api.dropboxapi.com",
        dropboxContent: "https://content.dropboxapi.com",
        googleAuthorize: "https://accounts.google.com/o/oauth2/v2/auth",
        googleToken: "https://oauth2.googleapis.com/token",
        googleRevoke: "https://oauth2.googleapis.com/revoke",
        googleAPI: "https://www.googleapis.com"
    )

    public init(
        dropboxAuthorize: String,
        dropboxAPI: String,
        dropboxContent: String,
        googleAuthorize: String,
        googleToken: String,
        googleRevoke: String,
        googleAPI: String
    ) {
        self.dropboxAuthorize = dropboxAuthorize
        self.dropboxAPI = dropboxAPI
        self.dropboxContent = dropboxContent
        self.googleAuthorize = googleAuthorize
        self.googleToken = googleToken
        self.googleRevoke = googleRevoke
        self.googleAPI = googleAPI
    }

    /// `base` + `path` + `query`, or an error naming the address that cannot be a URL.
    static func url(_ base: String, _ path: String = "", query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: base + path) else { throw UploadError.failed("Bad address: \(base)\(path)") }
        if !query.isEmpty {
            components.percentEncodedQuery = FormEncoding.encode(query)
        }
        guard let url = components.url else { throw UploadError.failed("Bad address: \(base)\(path)") }
        return url
    }
}
