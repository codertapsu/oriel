import Foundation
import ServiceManagement

/// Read as Administrator without a password each time (PLAN §7.10 item 17): a launchd daemon in Oriel's bundle,
/// `Contents/Library/LaunchDaemons/<bundle ID>.disk-reader.plist`, that runs Oriel's own executable as root
/// (`PrivilegedReaderDaemon`) and answers one XPC request, list these folders by the scan's rules. The user installs it
/// from the window or Settings and switches it on once in System Settings → General → Login Items & Extensions, where
/// macOS asks for an administrator's password; from then on scans read those folders without asking. Each end checks the
/// other's code signature (`CodeIdentity`), so no other app can use it; it answers administrators only
/// (`Administrators`), and it reads and replies, nothing else. Only the window's scans use it, never the CLI's.
///
/// An update replaces the executable launchd starts, and `SMAppService`'s header says a daemon may not launch until it is
/// registered again, so the window registers it again the first time it is used after an update (`reinstall`), and once
/// more when it does not answer.
public nonisolated enum PrivilegedReader {
    public enum Status: Sendable, Equatable {
        /// This build has no helper (none in the bundle, or no team in the signature), or the user is not an
        /// administrator, the only one it answers.
        case unavailable
        case notInstalled
        /// Installed, waiting for the user to switch it on in System Settings.
        case needsApproval
        case allowed
    }

    /// `<bundle ID>.disk-reader`: the launchd label, the Mach service, and the property list's name.
    static func label(for bundleIdentifier: String) -> String {
        bundleIdentifier + ".disk-reader"
    }

    static var label: String? {
        Bundle.main.bundleIdentifier.map(label(for:))
    }

    /// The running build, which `reinstall` is tied to.
    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private static var service: SMAppService? {
        guard let label else { return nil }
        let plist = Bundle.main.bundleURL.appending(path: "Contents/Library/LaunchDaemons/\(label).plist")
        guard FileManager.default.fileExists(atPath: plist.path) else { return nil }
        return SMAppService.daemon(plistName: plist.lastPathComponent)
    }

    /// Another user's Oriel sees the daemon an administrator allowed, Mac-wide, but is refused by it, so it never
    /// uses, registers or removes it.
    public static var status: Status {
        guard let service, CodeIdentity.ownRequirement() != nil, Administrators.contains(getuid()) else { return .unavailable }
        return status(of: service.status)
    }

    static func status(of status: SMAppService.Status) -> Status {
        switch status {
        case .enabled: .allowed
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .notInstalled
        @unknown default: .notInstalled
        }
    }

    /// Registers the helper, after which macOS lists it in Login Items to be switched on. Registering one that is
    /// already registered is not an error here.
    public static func install() throws {
        guard let service else { return }
        do {
            try service.register()
        } catch {
            guard status(of: service.status) != .notInstalled else { throw error }
        }
    }

    /// Unregisters it: from Settings, and when Oriel is uninstalled.
    public static func uninstall() {
        try? service?.unregister()
    }

    /// Registers it again for a new executable: after an update, or when it did not answer.
    static func reinstall() {
        guard let service else { return }
        try? service.unregister()
        try? service.register()
    }

    public static func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Long enough for the largest owner-only folders; a helper that has not answered by then never will.
    static let timeout: Duration = .seconds(300)

    /// Lists the folders through the helper.
    static func read(_ request: ElevatedRead.Request) async -> ElevatedRead.Outcome {
        guard let label, let requirement = CodeIdentity.ownRequirement() else {
            return .failed("This build of Oriel has no helper.")
        }
        let connection = NSXPCConnection(machServiceName: label, options: .privileged)
        connection.setCodeSigningRequirement(requirement)
        return await read(request, over: connection)
    }

    /// Sends the request over `connection`, which it resumes and then invalidates; after `timeout` without an answer it
    /// gives up. Tests hand in a connection to an anonymous listener.
    static func read(
        _ request: ElevatedRead.Request,
        over connection: NSXPCConnection,
        timeout: Duration = PrivilegedReader.timeout
    ) async -> ElevatedRead.Outcome {
        connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedReading.self)
        connection.resume()
        // Invalidating the connection makes its error handler answer, if nothing has. NSXPCConnection is thread-safe but
        // not marked Sendable.
        nonisolated(unsafe) let watched = connection
        let watchdog = Task {
            try? await Task.sleep(for: timeout)
            if !Task.isCancelled {
                watched.invalidate()
            }
        }
        defer {
            watchdog.cancel()
            connection.invalidate()
        }
        return await withCheckedContinuation { continuation in
            let answer = ReplyOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                answer.give(.failed(error.localizedDescription))
            } as? PrivilegedReading
            guard let proxy else {
                answer.give(.failed("Oriel's helper could not be reached."))
                return
            }
            proxy.readFolders(request.arguments) { data, reason in
                guard let data, let result = try? JSONDecoder().decode(ElevatedRead.Result.self, from: data),
                      result.version == ElevatedRead.version
                else {
                    answer.give(.failed(reason ?? "Oriel could not make sense of what its helper read."))
                    return
                }
                answer.give(.read(result))
            }
        }
    }
}
