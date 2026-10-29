import Foundation

/// Reads Google Drive's answers and maps its errors (`error.errors[].reason`) onto what the user can do about them.
nonisolated enum GoogleDriveResponses {
    struct File: Equatable {
        let id: String
        let name: String
        let webViewLink: URL?
        let webContentLink: URL?
    }

    static func file(_ data: Data) throws -> File {
        let object = json(data)
        guard let id = object["id"] as? String, !id.isEmpty else {
            throw UploadError.failed("Google Drive did not say which file it made.")
        }
        return File(
            id: id,
            name: object["name"] as? String ?? "",
            webViewLink: (object["webViewLink"] as? String).flatMap(URL.init(string:)),
            webContentLink: (object["webContentLink"] as? String).flatMap(URL.init(string:))
        )
    }

    /// The ID of the first file a `files.list` returns.
    static func firstFileID(_ data: Data) -> String? {
        ((json(data)["files"] as? [[String: Any]])?.first?["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The next byte to send, from a 308 answer's `Range: bytes=0-<last>`; 0 when nothing arrived yet.
    static func nextOffset(range: String?) -> Int64 {
        guard let range, let dash = range.lastIndex(of: "-"), let last = Int64(range[range.index(after: dash)...]) else { return 0 }
        return last + 1
    }

    /// "Marcus Ng (marcus@example.com)", from `about.get`.
    static func accountName(_ data: Data) -> String? {
        let user = json(data)["user"] as? [String: Any]
        let name = user?["displayName"] as? String
        let email = user?["emailAddress"] as? String
        switch (name, email) {
        case let (name?, email?): return "\(name) (\(email))"
        case let (nil, email?): return email
        case let (name?, nil): return name
        default: return nil
        }
    }

    /// The `reason` of the first error, and Google's message.
    static func reason(_ body: Data) -> (reason: String, message: String) {
        let error = json(body)["error"] as? [String: Any]
        let first = (error?["errors"] as? [[String: Any]])?.first
        let reason = first?["reason"] as? String ?? (error?["status"] as? String ?? "")
        let message = error?["message"] as? String ?? first?["message"] as? String ?? ""
        return (reason, message)
    }

    static func error(status: Int, body: Data) -> UploadError {
        let (reason, message) = reason(body)
        switch (status, reason) {
        case (401, _):
            return .signInRequired(service: "Google Drive")
        case (_, "accessNotConfigured"), (_, "SERVICE_DISABLED"):
            return .invalidSettings(
                "The Google Drive API is off for your Google Cloud project. Turn it on in the Cloud console, then try again."
            )
        case (_, "storageQuotaExceeded"), (_, "quotaExceeded"):
            return .quotaExceeded("Your Google Drive is full.")
        case (_, "rateLimitExceeded"), (_, "userRateLimitExceeded"), (429, _):
            return .rateLimited("Google Drive is limiting requests. Try again in a minute.")
        case (_, "insufficientPermissions"), (_, "ACCESS_TOKEN_SCOPE_INSUFFICIENT"):
            return .forbidden("Oriel's sign-in doesn't cover this. Sign in to Google Drive again.")
        case (404, _), (_, "notFound"):
            return .notFound(
                "Google Drive can't find the folder, or Oriel may not use it. With “Only files Oriel uploads”, use a folder Oriel made, "
                    + "or leave Folder empty."
            )
        case (403, _):
            return .forbidden(message.isEmpty ? "Google Drive doesn't let this account add files there." : message)
        case (500 ... 599, _):
            return .server(status: status, message: "Google Drive is having trouble.")
        default:
            return .server(status: status, message: message)
        }
    }

    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
