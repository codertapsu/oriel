import Foundation

/// One sign-in in progress: the page to open, the redirect scheme to catch, and the verifier and state its answer is
/// checked with. Made fresh for every sign-in and never stored.
nonisolated struct OAuthAuthorization: Sendable, Equatable {
    let url: URL
    let callbackScheme: String
    let pkce: PKCE
    let state: String
    let service: String
}
