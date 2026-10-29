import Foundation

/// An SSH server reached with the system's OpenSSH client, `/usr/bin/sftp`, in batch mode: it signs in with the
/// user's key or ssh-agent and checks the server against `~/.ssh/known_hosts`, and reads `~/.ssh/config`, so a host
/// alias works. There is no password: batch mode never asks for one.
public nonisolated struct SFTPConfiguration: Codable, Sendable, Equatable {
    /// A host name, an address, or a `Host` alias from `~/.ssh/config`.
    public var host: String
    /// Nil: port 22, or the one `~/.ssh/config` gives.
    public var port: Int?
    /// Empty: the user `~/.ssh/config` gives, else the Mac's user name.
    public var username: String
    /// Absolute, or relative to the login folder; it must exist. Empty: the login folder.
    public var remoteFolder: String
    /// A private key file, for a key `~/.ssh/config` does not name. Empty: ssh's own choice and the agent.
    public var identityFile: String
    /// The link to copy, e.g. `https://files.example.com/{path}`. Empty: an `sftp://` address.
    public var publicURLTemplate: String

    public init(
        host: String = "",
        port: Int? = nil,
        username: String = "",
        remoteFolder: String = "",
        identityFile: String = "",
        publicURLTemplate: String = ""
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.remoteFolder = remoteFolder
        self.identityFile = identityFile
        self.publicURLTemplate = publicURLTemplate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            host: container.decodeIfPresent(String.self, forKey: .host) ?? "",
            port: container.decodeIfPresent(Int.self, forKey: .port),
            username: container.decodeIfPresent(String.self, forKey: .username) ?? "",
            remoteFolder: container.decodeIfPresent(String.self, forKey: .remoteFolder) ?? "",
            identityFile: container.decodeIfPresent(String.self, forKey: .identityFile) ?? "",
            publicURLTemplate: container.decodeIfPresent(String.self, forKey: .publicURLTemplate) ?? ""
        )
    }

    /// The host without spaces around it, and without a `user@` typed into it.
    public var trimmedHost: String {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard let at = host.lastIndex(of: "@") else { return host }
        return String(host[host.index(after: at)...])
    }

    /// The user name, or the one typed as `user@host`.
    public var effectiveUsername: String {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard name.isEmpty else { return name }
        let host = host.trimmingCharacters(in: .whitespaces)
        guard let at = host.lastIndex(of: "@") else { return "" }
        return String(host[..<at])
    }

    public var trimmedRemoteFolder: String {
        remoteFolder.trimmingCharacters(in: .whitespaces)
    }

    /// The key file with `~` expanded, or nil when none is set.
    public var expandedIdentityFile: String? {
        let path = identityFile.trimmingCharacters(in: .whitespaces)
        return path.isEmpty ? nil : (path as NSString).expandingTildeInPath
    }

    /// What is still missing, in words, or nil when uploads can start.
    public var missingField: String? {
        trimmedHost.isEmpty ? "a host" : nil
    }

    /// Why these settings cannot be handed to sftp safely, or nil. Host and user name become ssh arguments, so they may
    /// not look like options; the folder goes into a batch file, where some characters mean something.
    public var problem: String? {
        let host = trimmedHost
        if host.hasPrefix("-") || host.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" || $0 == "\\" }) {
            return "The host can't start with “-” or contain spaces, quotes or backslashes."
        }
        let user = effectiveUsername
        if user.hasPrefix("-") || user.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) {
            return "The user name can't start with “-” or contain spaces or quotes."
        }
        if let port, !(1 ... 65535).contains(port) {
            return "The port must be between 1 and 65535."
        }
        if !trimmedRemoteFolder.isEmpty, SFTPBatch.quoted(trimmedRemoteFolder) == nil {
            return "The folder can't contain quotes, backslashes, *, ?, [ or ], or line breaks."
        }
        if let key = expandedIdentityFile, key.contains(where: \.isNewline) {
            return "The key file's path can't contain line breaks."
        }
        return nil
    }
}
