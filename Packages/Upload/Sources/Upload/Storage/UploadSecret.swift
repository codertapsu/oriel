import Foundation

/// The secrets a destination can have. Each is a Keychain item of the service `UploadSettings.keychainService`, with
/// the account `<destination ID>.<raw value>`, so Uninstall removes them all with the service.
public nonisolated enum UploadSecret: String, CaseIterable, Sendable {
    /// S3's secret access key.
    case secretKey
    /// WebDAV's password.
    case password
    /// Dropbox's or Google Drive's tokens, as `OAuthTokens` JSON.
    case oauthTokens = "oauth"

    public func account(for destination: UUID) -> String {
        "\(destination.uuidString).\(rawValue)"
    }

    /// The word for it in messages ("“Team NAS” has no password in the keychain").
    public var title: String {
        switch self {
        case .secretKey: "secret key"
        case .password: "password"
        case .oauthTokens: "sign-in"
        }
    }

    /// The secret a destination of `kind` has, if any. SFTP has none: it signs in with the user's SSH key.
    public static func secret(for kind: UploadDestinationKind) -> UploadSecret? {
        switch kind {
        case .s3: .secretKey
        case .webDAV: .password
        case .dropbox, .googleDrive: .oauthTokens
        case .sftp, .sharedFolder: nil
        }
    }
}
