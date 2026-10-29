import Foundation

/// Opens a service's sign-in page and returns the redirect it ends with: the seam between Dropbox and Google Drive
/// sign-in and `ASWebAuthenticationSession`, so tests hand in a fake and never open a browser.
@MainActor
public protocol WebAuthenticating: AnyObject {
    /// Shows `url` and returns the first navigation to `callbackScheme`; throws `UploadError.cancelled` when the user
    /// closes the sheet.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}
