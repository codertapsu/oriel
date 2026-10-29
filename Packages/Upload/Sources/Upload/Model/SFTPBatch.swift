import Foundation

/// The `sftp` command line and the batch file it reads from standard input (`-b -`).
///
/// sftp splits batch lines itself: quotes group words, a backslash escapes, `*`, `?`, `[` and `]` are wildcards for
/// some commands and not others, and `#` starts a comment outside quotes. Every path is therefore double-quoted, and a
/// path with a character that would still mean something inside the quotes (`"`, `\`, a wildcard, a line break) is
/// refused rather than escaped. Names from the template are made safe first (`safeName`), and the local file is always
/// one Oriel named. Relative paths start with `./`, so a name beginning with `-` is never read as an option.
nonisolated enum SFTPBatch {
    static let executable = URL(fileURLWithPath: "/usr/bin/sftp")
    /// What sftp prints for `pwd`.
    static let workingDirectoryPrefix = "Remote working directory: "

    /// `"path"`, or nil when the path cannot be written into a batch file safely.
    static func quoted(_ path: String) -> String? {
        let refused = CharacterSet(charactersIn: "\"\\*?[]").union(.controlCharacters).union(.newlines)
        guard !path.isEmpty, path.unicodeScalars.allSatisfy({ !refused.contains($0) }) else { return nil }
        return "\"\(path)\""
    }

    /// A template-made name with sftp's wildcard brackets turned into parentheses (the other unsafe characters are
    /// gone already, `UploadNameTemplate.sanitize`).
    static func safeName(_ segment: String) -> String {
        UploadNameTemplate.sanitize(segment.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")"))
    }

    /// No prompts (no password, no passphrase, no "are you sure"), only hosts already in `known_hosts`, and a dead
    /// connection noticed within half a minute. `~/.ssh/config` still applies, so aliases, keys and agents work.
    static func arguments(for configuration: SFTPConfiguration) -> [String] {
        var arguments = [
            "-b", "-",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=20",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=2",
        ]
        if let port = configuration.port {
            arguments += ["-P", String(port)]
        }
        let user = configuration.effectiveUsername
        if !user.isEmpty {
            arguments += ["-o", "User=\(user)"]
        }
        if let key = configuration.expandedIdentityFile {
            // Only that key, so an agent full of other keys does not use up the server's attempts first.
            arguments += ["-i", key, "-o", "IdentitiesOnly=yes"]
        }
        arguments.append(configuration.trimmedHost)
        return arguments
    }

    /// Goes to the folder, prints where that is, makes the file's folders (an existing one is fine: `-` ignores the
    /// error) and uploads the file.
    static func uploadScript(folder: String, path: [String], localFile: String) throws -> String {
        var lines = try preamble(folder: folder)
        let folders = path.dropLast()
        for count in folders.indices.map({ $0 + 1 }) {
            try lines.append("-mkdir \(quote(relative(Array(folders.prefix(count)))))")
        }
        try lines.append("put \(quote(localFile)) \(quote(relative(path)))")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Goes to the folder and prints where that is: what Test Connection runs.
    static func testScript(folder: String) throws -> String {
        try preamble(folder: folder).joined(separator: "\n") + "\n"
    }

    /// The absolute folder from `pwd`'s line in sftp's output.
    static func workingDirectory(in output: String) -> String? {
        output.split(whereSeparator: \.isNewline).lazy.compactMap { line -> String? in
            guard let range = line.range(of: workingDirectoryPrefix) else { return nil }
            let directory = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return directory.isEmpty ? nil : directory
        }.first
    }

    /// sftp starts in the login folder, so `~/uploads` is `./uploads`; older servers cannot expand `~` themselves.
    private static func preamble(folder: String) throws -> [String] {
        var folder = folder.trimmingCharacters(in: .whitespaces)
        if folder == "~" {
            folder = ""
        } else if folder.hasPrefix("~/") {
            folder = "./" + folder.dropFirst(2)
        }
        guard !folder.isEmpty else { return ["pwd"] }
        let target = folder.hasPrefix("/") || folder.hasPrefix("./") || folder.hasPrefix("../") ? folder : "./" + folder
        return try ["cd \(quote(target))", "pwd"]
    }

    private static func relative(_ segments: [String]) -> String {
        "./" + segments.joined(separator: "/")
    }

    private static func quote(_ path: String) throws -> String {
        guard let quoted = quoted(path) else {
            throw UploadError.invalidSettings("The path “\(path)” has a character sftp can't take (quotes, backslashes, *, ?, [ or ]).")
        }
        return quoted
    }
}
