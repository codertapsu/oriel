import AppKit
import AuthenticationServices

/// `ASWebAuthenticationSession` in a sheet over the Settings window. It catches the redirect to a custom scheme itself,
/// so Oriel registers no URL scheme and runs no local server for it. The browser session is shared with the user's
/// default browser, so someone already signed in to Dropbox or Google only has to approve.
@MainActor
final class WebAuthenticator: NSObject, WebAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        session?.cancel()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { [weak self] callbackURL, error in
                Task { @MainActor in self?.session = nil }
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: UploadError.cancelled)
                } else {
                    let message = error?.localizedDescription ?? "The sign-in ended without an answer."
                    continuation.resume(throwing: UploadError.failed(message))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: UploadError.failed("The sign-in window could not open."))
            }
        }
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.canBecomeKey } ?? NSWindow()
    }
}
