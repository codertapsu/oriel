import Foundation

/// Why an upload, a connection test or a sign-in failed, worded so the user knows what to do next. Messages name hosts
/// and folders, so they are logged `privacy: .private`; they never contain passwords, tokens or signed URLs.
public nonisolated enum UploadError: LocalizedError, Sendable, Equatable {
    /// There is no destination at all.
    case noDestination
    /// The destination lacks a setting: its name, and what is missing ("a server address").
    case notConfigured(destination: String, missing: String)
    /// A setting cannot work as typed; the message says which and why.
    case invalidSettings(String)
    /// A password or key the destination needs is not in the keychain.
    case missingSecret(destination: String, secret: String)
    /// The service's sign-in is gone (revoked, expired or never made).
    case signInRequired(service: String)
    /// The server refused the credentials.
    case unauthorized(String)
    /// Signed in, but not allowed to do this.
    case forbidden(String)
    /// The server, folder or file is not there.
    case notFound(String)
    case quotaExceeded(String)
    case tooLarge(String)
    case rateLimited(String)
    case offline
    case timedOut
    /// The server could not be reached; the message says how.
    case unreachable(String)
    /// SFTP: `~/.ssh/known_hosts` has no key for the host, and strict checking refuses it.
    case hostKeyUnknown(host: String)
    /// SFTP: the host's key differs from the one in `~/.ssh/known_hosts`.
    case hostKeyChanged(host: String)
    case keychain(String)
    case server(status: Int, message: String)
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noDestination:
            "Uploads are not set up yet. Add a destination in Settings → Upload."
        case let .notConfigured(destination, missing):
            "“\(destination)” needs \(missing). Finish it in Settings → Upload."
        case let .missingSecret(destination, secret):
            "“\(destination)” has no \(secret) in the keychain. Enter it in Settings → Upload."
        case let .signInRequired(service):
            "Sign in to \(service) again in Settings → Upload."
        case let .invalidSettings(message), let .unauthorized(message), let .forbidden(message), let .notFound(message),
             let .quotaExceeded(message), let .tooLarge(message), let .rateLimited(message), let .unreachable(message),
             let .failed(message):
            message
        case .offline:
            "This Mac is offline."
        case .timedOut:
            "The server took too long to answer."
        case let .hostKeyUnknown(host):
            "This Mac doesn't know the host key of \(host) yet. In Terminal, run “ssh \(host)” once and accept the key, then try again."
        case let .hostKeyChanged(host):
            "The host key of \(host) has changed. If you expected that, run “ssh-keygen -R \(host)” in Terminal and connect "
                + "once; otherwise someone may be intercepting the connection."
        case let .keychain(message):
            "The keychain could not be read: \(message)"
        case let .server(status, message) where message.isEmpty:
            "The server refused the upload (HTTP \(status))."
        case let .server(status, message):
            "The server refused the upload (HTTP \(status)): \(message)"
        case .cancelled:
            "Upload cancelled."
        }
    }

    /// Any error as an `UploadError`.
    public static func from(_ error: any Error) -> UploadError {
        if let error = error as? UploadError {
            return error
        }
        if error is CancellationError {
            return .cancelled
        }
        if let error = error as? URLError {
            return from(error)
        }
        return .failed(error.localizedDescription)
    }

    static func from(_ error: URLError) -> UploadError {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            .offline
        case .networkConnectionLost:
            .unreachable("The connection was lost. Try again.")
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        case .cannotFindHost, .dnsLookupFailed:
            .unreachable("Oriel can't find that server. Check the address.")
        case .cannotConnectToHost:
            .unreachable("Nothing answers at that address. Is the server running?")
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired:
            .unreachable("The secure connection failed: \(error.localizedDescription)")
        case .appTransportSecurityRequiresSecureConnection:
            .invalidSettings("Plain HTTP works only for servers on the local network. Use an https:// address.")
        case .userAuthenticationRequired, .userCancelledAuthentication:
            .unauthorized("The server refused the user name or password.")
        default:
            .unreachable(error.localizedDescription)
        }
    }

    /// The usual meaning of an HTTP status, for services without error details of their own.
    static func from(status: Int, message: String) -> UploadError {
        switch status {
        case 401: .unauthorized("The server refused the user name or password.")
        case 403: .forbidden(message.isEmpty ? "The server doesn't allow this. Check the account's rights on the folder." : message)
        case 404: .notFound(message.isEmpty ? "The server has nothing at that address." : message)
        case 413: .tooLarge("The file is larger than the server accepts.")
        case 429: .rateLimited("The server is limiting requests. Try again in a minute.")
        case 507: .quotaExceeded("The server has no space left.")
        default: .server(status: status, message: message)
        }
    }

    /// Whether the user did this, so nothing needs saying beyond "cancelled".
    public var isCancellation: Bool {
        self == .cancelled
    }

    /// Whether the connection failed rather than the server saying no, so sending the same thing again may work.
    var isConnectionProblem: Bool {
        switch self {
        case .offline, .timedOut, .unreachable: true
        default: false
        }
    }
}
