import Foundation

/// Reads the redirect a sign-in ends with, `db-<key>://2/token?code=…&state=…` or
/// `com.googleusercontent.apps.<id>:/oauth2redirect?code=…&state=…`, or the error the service sent instead.
nonisolated enum OAuthCallback {
    /// The authorization code, once `state` has been checked against the one Oriel sent, which shows the answer
    /// belongs to this sign-in (RFC 6749 §10.12).
    static func code(from url: URL, expectedState: String, service: String) throws -> String {
        let parameters = parameters(of: url)
        if let error = parameters["error"] {
            if error == "access_denied" {
                throw UploadError.forbidden("Oriel wasn't allowed into your \(service), so it can't upload there.")
            }
            let description = parameters["error_description"].map { $0.replacingOccurrences(of: "+", with: " ") } ?? error
            throw UploadError.failed("\(service) refused the sign-in: \(description)")
        }
        guard parameters["state"] == expectedState else {
            throw UploadError.failed("The answer from \(service) did not belong to this sign-in. Try again.")
        }
        guard let code = parameters["code"], !code.isEmpty else {
            throw UploadError.failed("\(service) did not send a sign-in code. Try again.")
        }
        return code
    }

    /// The query's parameters, and the fragment's, which some services use instead.
    static func parameters(of url: URL) -> [String: String] {
        var parameters: [String: String] = [:]
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return parameters }
        var items = components.queryItems ?? []
        if let fragment = components.fragment, var fragmentComponents = URLComponents(string: "x:/") {
            fragmentComponents.query = fragment
            items += fragmentComponents.queryItems ?? []
        }
        for item in items where parameters[item.name] == nil {
            parameters[item.name] = item.value ?? ""
        }
        return parameters
    }
}
