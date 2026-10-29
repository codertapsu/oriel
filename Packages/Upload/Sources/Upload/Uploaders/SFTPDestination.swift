import Foundation

/// An SSH server through `/usr/bin/sftp` in batch mode (`SFTPBatch`): the system's OpenSSH reads `~/.ssh/config`,
/// signs in with the user's key or agent and checks `~/.ssh/known_hosts`, so Oriel holds no password and no key.
/// sftp prints no progress in batch mode, so the progress bar is indeterminate.
nonisolated struct SFTPDestination: DestinationUploader {
    let configuration: SFTPConfiguration
    let runner: any ProcessRunning

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        try check()
        let safePath = path.map(SFTPBatch.safeName).filter { !$0.isEmpty }
        // sftp is handed a file Oriel named, so nothing in the user's own file name can mean something to it.
        let folder = try PayloadPreparer.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let local = folder.appending(path: "upload")
        try FileManager.default.createSymbolicLink(at: local, withDestinationURL: payload.fileURL)
        let script = try SFTPBatch.uploadScript(folder: configuration.trimmedRemoteFolder, path: safePath, localFile: local.path)
        progress(.sending(0, of: nil))
        let result = try await run(script)
        let remoteFolder = SFTPBatch.workingDirectory(in: result.outputText)
        let templated = UploadLinkTemplate.link(configuration.publicURLTemplate, path: safePath)
        guard let link = templated ?? sftpLink(folder: remoteFolder, path: safePath) else {
            throw UploadError.failed("The file is on the server, but Oriel could not make a link to it.")
        }
        return UploadReceipt(link: link, path: safePath)
    }

    /// Signs in, goes to the folder and asks where that is, without changing anything.
    func testConnection() async throws -> String {
        try check()
        let result = try await run(SFTPBatch.testScript(folder: configuration.trimmedRemoteFolder))
        let folder = SFTPBatch.workingDirectory(in: result.outputText) ?? configuration.trimmedRemoteFolder
        let connected = "Connected to \(configuration.trimmedHost)."
        return folder.isEmpty ? connected : "\(connected) Uploads go to \(folder)."
    }

    private func check() throws {
        if let missing = configuration.missingField {
            throw UploadError.notConfigured(destination: "SFTP", missing: missing)
        }
        if let problem = configuration.problem {
            throw UploadError.invalidSettings(problem)
        }
    }

    private func run(_ script: String) async throws -> ProcessResult {
        let result = try await runner.run(
            SFTPBatch.executable,
            arguments: SFTPBatch.arguments(for: configuration),
            input: Data(script.utf8)
        )
        guard result.status == 0 else {
            throw SFTPFailure.error(
                status: result.status, standardError: result.errorText, host: configuration.trimmedHost,
                folder: configuration.trimmedRemoteFolder
            )
        }
        return result
    }

    /// `sftp://user@host:port/absolute/path`, for when no public URL is set.
    func sftpLink(folder: String?, path: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = "sftp"
        components.host = configuration.trimmedHost
        let user = configuration.effectiveUsername
        components.user = user.isEmpty ? nil : user
        components.port = configuration.port
        let base = UploadPath.segments(folder ?? "")
        components.percentEncodedPath = "/" + UploadLinkTemplate.encodedPath(base + path)
        return components.url
    }
}
