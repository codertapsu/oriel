import Foundation

/// Reads Dropbox's answers and maps its errors (`error_summary`, such as `path/insufficient_space/...`) onto what the
/// user can do about them.
nonisolated enum DropboxResponses {
    /// The uploaded file's path, which differs from the one sent when Dropbox renamed it to avoid a name in use.
    static func uploadedPath(_ data: Data) throws -> String {
        let object = json(data)
        guard let path = object["path_display"] as? String ?? object["path_lower"] as? String else {
            throw UploadError.failed("Dropbox did not say where it put the file.")
        }
        return path
    }

    static func sessionID(_ data: Data) throws -> String {
        guard let id = json(data)["session_id"] as? String, !id.isEmpty else {
            throw UploadError.failed("Dropbox did not start the upload.")
        }
        return id
    }

    static func sharedLink(_ data: Data) throws -> URL {
        guard let text = json(data)["url"] as? String, let url = URL(string: text) else {
            throw UploadError.failed("Dropbox did not send a link.")
        }
        return url
    }

    /// Whether creating a link failed only because the file already has one.
    static func linkAlreadyExists(status: Int, body: Data) -> Bool {
        status == 409 && summary(body).hasPrefix("shared_link_already_exists")
    }

    /// The existing link that a `shared_link_already_exists` error carries, when it carries one.
    static func existingLink(_ body: Data) -> URL? {
        let error = json(body)["error"] as? [String: Any]
        return firstURL(in: error?["shared_link_already_exists"])
    }

    /// The first link `list_shared_links` returns.
    static func firstLink(_ data: Data) -> URL? {
        let links = json(data)["links"] as? [[String: Any]] ?? []
        return links.lazy.compactMap { ($0["url"] as? String).flatMap(URL.init(string:)) }.first
    }

    /// "Marcus Ng (marcus@example.com)", from `users/get_current_account`.
    static func accountName(_ data: Data) -> String? {
        let object = json(data)
        let email = object["email"] as? String
        let name = (object["name"] as? [String: Any])?["display_name"] as? String
        switch (name, email) {
        case let (name?, email?): return "\(name) (\(email))"
        case let (nil, email?): return email
        case let (name?, nil): return name
        default: return nil
        }
    }

    /// A 401 that a refresh fixes.
    static func isExpiredToken(status: Int, body: Data) -> Bool {
        status == 401 && summary(body).hasPrefix("expired_access_token")
    }

    /// Where an upload session really is, from an `incorrect_offset` error (at the top of the error, or under
    /// `lookup_failed` for a commit).
    static func correctOffset(_ body: Data) -> Int64? {
        guard summary(body).contains("incorrect_offset") else { return nil }
        return firstNumber(named: "correct_offset", in: json(body)["error"])
    }

    static func error(status: Int, body: Data, folder: String) -> UploadError {
        let summary = summary(body)
        let place = folder.isEmpty ? "your Dropbox" : "“\(folder)”"
        switch status {
        case 400:
            let text = body.prefix(300).utf8Text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.localizedCaseInsensitiveContains("app key") || text.localizedCaseInsensitiveContains("client_id") {
                return .invalidSettings("Dropbox doesn't recognize this app key. Check it in Settings → Upload.")
            }
            return .failed(text.isEmpty ? "Dropbox refused the request." : "Dropbox refused the request: \(text)")
        case 401:
            if summary.hasPrefix("missing_scope") {
                let scope = ((json(body)["error"] as? [String: Any])?["required_scope"] as? String) ?? "a needed"
                return .forbidden(
                    "Your Dropbox app lacks the \(scope) permission. Turn it on in the App Console's Permissions tab, then sign in again."
                )
            }
            return .signInRequired(service: "Dropbox")
        case 403:
            return .forbidden("Dropbox doesn't allow this account to do that.")
        case 409:
            return conflict(summary, place: place)
        case 429:
            return .rateLimited("Dropbox is limiting requests. Try again in a minute.")
        case 500 ... 599:
            return .server(status: status, message: "Dropbox is having trouble.")
        default:
            return .server(status: status, message: summary)
        }
    }

    private static func conflict(_ summary: String, place: String) -> UploadError {
        if summary.contains("insufficient_space") {
            return .quotaExceeded("Your Dropbox is full.")
        }
        if summary.contains("no_write_permission") {
            return .forbidden("Your Dropbox app can't write to \(place).")
        }
        if summary.contains("malformed_path") || summary.contains("disallowed_name") {
            return .invalidSettings("Dropbox can't use that name or folder (\(place)).")
        }
        if summary.contains("too_many_write_operations") {
            return .rateLimited("Dropbox is busy with other changes to this account. Try again in a moment.")
        }
        if summary.contains("email_not_verified") {
            return .forbidden("Dropbox shares links only once the account's email address is verified.")
        }
        if summary.contains("not_authorized") || summary.contains("access_denied") {
            return .forbidden("Your Dropbox team doesn't allow shared links for this file.")
        }
        return .failed(summary.isEmpty ? "Dropbox refused the request." : "Dropbox refused the request (\(summary)).")
    }

    static func summary(_ body: Data) -> String {
        json(body)["error_summary"] as? String ?? ""
    }

    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private static func firstNumber(named name: String, in value: Any?) -> Int64? {
        guard let object = value as? [String: Any] else { return nil }
        if let number = object[name] as? NSNumber {
            return number.int64Value
        }
        return object.values.lazy.compactMap { firstNumber(named: name, in: $0) }.first
    }

    private static func firstURL(in value: Any?) -> URL? {
        if let object = value as? [String: Any] {
            if let text = object["url"] as? String, let url = URL(string: text) {
                return url
            }
            for nested in object.values {
                if let url = firstURL(in: nested) {
                    return url
                }
            }
        }
        return nil
    }
}
