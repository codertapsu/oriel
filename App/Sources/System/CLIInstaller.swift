import AppKit

/// Settings → Advanced → "Install command-line tool…" (PLAN §7.1.8): a symlink to the CLI inside the bundle,
/// in ~/.local/bin (no password) or /usr/local/bin (one admin prompt).
enum CLIInstaller {
    enum Location: CaseIterable {
        case user, system

        var directory: URL {
            switch self {
            case .user: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin", directoryHint: .isDirectory)
            case .system: URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
            }
        }

        var link: URL {
            directory.appending(path: "oriel")
        }
    }

    /// `Oriel.app/Contents/Helpers/oriel`.
    static var embeddedCLI: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/oriel")
    }

    /// Where a link to this copy of the CLI already exists.
    static var installedLocations: [Location] {
        Location.allCases.filter { location in
            (try? FileManager.default.destinationOfSymbolicLink(atPath: location.link.path)) == embeddedCLI.path
        }
    }

    static func install(_ location: Location) throws {
        switch location {
        case .user:
            try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: location.link)
            try FileManager.default.createSymbolicLink(at: location.link, withDestinationURL: embeddedCLI)
        case .system:
            try runAsAdministrator("mkdir -p /usr/local/bin && ln -sf \(quoted(embeddedCLI.path)) /usr/local/bin/oriel")
        }
    }

    static func uninstall(_ location: Location) throws {
        switch location {
        case .user: try FileManager.default.removeItem(at: location.link)
        case .system: try runAsAdministrator("rm -f /usr/local/bin/oriel")
        }
    }

    /// `do shell script … with administrator privileges`: the standard macOS password prompt, nothing stored.
    private static func runAsAdministrator(_ command: String) throws {
        let source = "do shell script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            throw NSError(
                domain: "Oriel.CLIInstaller",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: error[NSAppleScript.errorMessage] as? String ?? "The command failed."]
            )
        }
    }

    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
