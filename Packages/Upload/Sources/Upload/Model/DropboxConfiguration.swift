import Foundation

/// A Dropbox account, through a Dropbox app the user creates (Oriel ships no app key of its own). Sign-in is OAuth 2
/// with PKCE and `token_access_type=offline`; the refresh token is in the Keychain.
public nonisolated struct DropboxConfiguration: Codable, Sendable, Equatable {
    /// Which of a shared link's forms to copy.
    public enum LinkStyle: String, Codable, CaseIterable, Sendable {
        /// Dropbox's page for the file (`dl=0`).
        case page
        /// The file itself, shown by the browser (`raw=1`): an image opens as an image.
        case raw
        /// A download (`dl=1`).
        case download

        public var title: String {
            switch self {
            case .page: "Dropbox page"
            case .raw: "The file itself"
            case .download: "A download"
            }
        }
    }

    /// The app key from the Dropbox App Console (its OAuth client ID).
    public var appKey: String
    /// The folder uploads go into, e.g. `/Oriel`. In an App folder app it is inside `Apps/<app name>`.
    public var folder: String
    public var linkStyle: LinkStyle

    public init(appKey: String = "", folder: String = "/Oriel", linkStyle: LinkStyle = .page) {
        self.appKey = appKey
        self.folder = folder
        self.linkStyle = linkStyle
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            appKey: container.decodeIfPresent(String.self, forKey: .appKey) ?? "",
            folder: container.decodeIfPresent(String.self, forKey: .folder) ?? "",
            linkStyle: container.decodeIfPresent(LinkStyle.self, forKey: .linkStyle) ?? .page
        )
    }

    public var trimmedAppKey: String {
        appKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The folder as a Dropbox path: `/`-led, without a trailing slash, `""` for the root.
    public var folderPath: String {
        let segments = UploadPath.segments(folder)
        return segments.isEmpty ? "" : "/" + UploadPath.joined(segments)
    }

    /// The redirect Oriel signs in with: the `db-<app key>` scheme, which Dropbox accepts for every app (its own SDKs
    /// use it), and which `ASWebAuthenticationSession` catches without a local server.
    public var redirectURI: String {
        "db-\(trimmedAppKey)://2/token"
    }

    public var callbackScheme: String {
        "db-\(trimmedAppKey)"
    }

    /// The permissions to tick on the app's Permissions tab: writing files, making links, and finding a file's link
    /// when it has one already.
    public static let requiredScopes = ["files.content.write", "sharing.write", "sharing.read"]

    /// What is still missing, in words, or nil.
    public var missingField: String? {
        trimmedAppKey.isEmpty ? "an app key" : nil
    }

    /// Why the app key cannot be right, or nil. App keys are short and alphanumeric; this catches a pasted secret or URL.
    public var problem: String? {
        let key = trimmedAppKey
        guard !key.isEmpty else { return nil }
        return key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } ? nil : "An app key has only letters and digits."
    }
}
