import Foundation

/// Turns a failed sftp run (its exit status and what ssh and sftp printed to standard error) into an error that says
/// what to do. The checks go from the most specific message to the most general, since one run prints several lines
/// ("Host key verification failed." is followed by "Connection closed").
nonisolated enum SFTPFailure {
    static func error(status: Int32, standardError: String, host: String, folder: String) -> UploadError {
        let text = standardError
        let place = folder.isEmpty ? "the login folder" : "“\(folder)”"
        if text.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || text.contains("POSSIBLE DNS SPOOFING") {
            return .hostKeyChanged(host: host)
        }
        if text.contains("Host key verification failed") || text.contains("host key is known for") {
            return .hostKeyUnknown(host: host)
        }
        // Before the refusal it causes: ssh skips a key it can't use, then the server says "Permission denied".
        if let message = keyFileProblem(text) {
            return .invalidSettings(message)
        }
        let refusals = ["Permission denied (", "Too many authentication failures", "No more authentication methods"]
        if refusals.contains(where: text.contains) {
            return .unauthorized(authenticationAdvice(host: host))
        }
        if text.contains("Could not resolve hostname") {
            return .unreachable("Oriel can't find the server “\(host)”. Check the host name.")
        }
        if text.contains("Connection refused") {
            return .unreachable("The server refused the connection. Is SSH running on it, on that port?")
        }
        if text.contains("Operation timed out") || text.contains("Connection timed out") || text.contains("Timeout, server") {
            return .timedOut
        }
        if text.contains("No route to host") || text.contains("Network is unreachable") {
            return .unreachable("This Mac can't reach “\(host)”. Check the network or VPN.")
        }
        if text.contains("subsystem request failed") {
            return .unreachable("“\(host)” accepts SSH but doesn't offer SFTP.")
        }
        if text.contains("message too long") {
            return .failed("The server's login script prints text, which breaks SFTP. Make it quiet for non-interactive logins.")
        }
        if text.contains("Couldn't canonicalize") || text.contains("Can't change directory") || text.contains("No such file or directory") {
            return .notFound("The folder \(place) doesn't exist on the server. Make it, or change the folder in Settings → Upload.")
        }
        if text.contains("Permission denied") {
            return .forbidden("The server doesn't let you write to \(place).")
        }
        if text.contains("No space left") || text.contains("quota") || text.contains("Quota") {
            return .quotaExceeded("The server has no space left.")
        }
        if text.contains("Connection reset") || text.contains("Connection closed") || text.contains("Broken pipe") {
            return .unreachable("The server closed the connection.")
        }
        let last = text.split(whereSeparator: \.isNewline).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return .failed(last.isEmpty ? "sftp stopped with status \(status)." : "sftp stopped with status \(status): \(last)")
    }

    /// What to do when the key is refused: Oriel never sends a password.
    static func authenticationAdvice(host: String) -> String {
        "The server refused your SSH key. Oriel signs in with a key or ssh-agent, never a password: run “ssh-copy-id \(host)” "
            + "in Terminal to install your key, and keep a key that has a passphrase in the agent with “ssh-add --apple-use-keychain”."
    }

    private static func keyFileProblem(_ text: String) -> String? {
        if text.contains("Identity file"), text.contains("not accessible") {
            return "The key file in Settings → Upload isn't there."
        }
        if text.contains("Load key"), text.contains("invalid format") || text.contains("error in libcrypto") {
            return "The key file in Settings → Upload isn't a private key ssh can read."
        }
        if text.contains("UNPROTECTED PRIVATE KEY FILE") {
            return "ssh won't use the key file because others can read it. In Terminal, run “chmod 600” on it."
        }
        return nil
    }
}
