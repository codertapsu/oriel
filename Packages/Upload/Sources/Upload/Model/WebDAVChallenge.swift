import Foundation

/// How a WebDAV upload answers the server's authentication challenge. URLSession works out Basic and Digest itself
/// once it has the credential; Oriel gives it once per request and refuses a second time, so a wrong password fails
/// at once instead of being retried.
nonisolated enum WebDAVChallenge {
    enum Answer: Equatable {
        case useCredential
        /// Let the system decide: server trust, or a challenge Oriel has no credential for (the 401 comes back).
        case performDefault
        /// The credential was refused already.
        case refuse
    }

    static func answer(method: String, previousFailures: Int, hasCredential: Bool) -> Answer {
        guard passwordMethods.contains(method), hasCredential else { return .performDefault }
        return previousFailures == 0 ? .useCredential : .refuse
    }

    static let passwordMethods: Set<String> = [
        NSURLAuthenticationMethodHTTPBasic,
        NSURLAuthenticationMethodHTTPDigest,
        NSURLAuthenticationMethodNTLM,
        NSURLAuthenticationMethodDefault,
    ]
}
