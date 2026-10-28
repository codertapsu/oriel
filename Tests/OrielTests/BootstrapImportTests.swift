import Foundation
@testable import Oriel
import OrielCore
import OrielTestSupport
import OrielTranslation
import Testing
import Upload

/// PLAN §13.1: importing `bootstrap.json` fills Settings and the Keychain, then deletes the file.
@MainActor
struct BootstrapImportTests {
    /// Settings in a throwaway defaults domain, the Keychain under a test prefix and a scratch folder.
    @MainActor
    private struct Sandbox {
        let suiteName = "com.codertapsu.oriel.tests.bootstrap.\(UUID().uuidString)"
        let keychain = KeychainStore(prefix: "com.codertapsu.oriel.tests.\(UUID().uuidString)")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("oriel-bootstrap-\(UUID().uuidString)")
        let settings: SettingsStore

        init() throws {
            settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        var file: URL {
            folder.appendingPathComponent("bootstrap.json")
        }

        func cleanUp() {
            UserDefaults().removePersistentDomain(forName: suiteName)
            try? keychain.remove(service: UploadSettings.keychainService)
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private static let example = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/bootstrap.example.json")

    @Test func importsTheDocumentedExampleAndDeletesTheFile() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        try FileManager.default.copyItem(at: Self.example, to: sandbox.file)
        var received: [(providers: [BootstrapProvider], defaultProvider: String?)] = []
        let importer = BootstrapImporter(settings: sandbox.settings, keychain: sandbox.keychain, file: sandbox.file) {
            received.append(($0, $1))
        }

        let summary = await importer.importAvailable()

        #expect(summary == "Imported 2 translation providers and the upload destination.")
        #expect(received.count == 1)
        #expect(received.first?.providers.map(\.id) == ["ollama", "anthropic"])
        #expect(received.first?.defaultProvider == "apple")
        let upload = sandbox.settings[UploadSettings.configuration]
        #expect(upload.endpoint == "https://minio.internal")
        #expect(upload.bucket == "oriel")
        #expect(upload.region == "us-east-1")
        #expect(upload.publicBaseURL == "https://files.internal/oriel")
        #expect(upload.usesPathStyle)
        #expect(sandbox.settings[AppSettings.lastBootstrapImport] != nil)
        #expect(!FileManager.default.fileExists(atPath: sandbox.file.path))
    }

    @Test func anUnsupportedVersionIsReportedAndTheFileIsKept() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        try Data(#"{ "version": 2 }"#.utf8).write(to: sandbox.file)
        var calls = 0
        let importer = BootstrapImporter(settings: sandbox.settings, keychain: sandbox.keychain, file: sandbox.file) { _, _ in
            calls += 1
        }

        let summary = try #require(await importer.importAvailable())

        #expect(summary.hasPrefix("bootstrap.json could not be read"))
        #expect(calls == 0)
        #expect(sandbox.settings[AppSettings.lastBootstrapImport] == nil)
        #expect(FileManager.default.fileExists(atPath: sandbox.file.path))
    }

    /// Writes to the login keychain, so it runs with the TCC tests on the dev Mac only.
    @Test(.requiresTCC) func theUploadSecretGoesToTheKeychainNotToSettings() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.cleanUp() }
        let config = #"""
        { "version": 1, "upload": { "kind": "s3", "endpoint": "https://s3.example.com", "bucket": "b",
          "accessKey": "AKIDEXAMPLE", "secretKey": "bootstrap-s3cr3t" } }
        """#
        try Data(config.utf8).write(to: sandbox.file)
        let importer = BootstrapImporter(settings: sandbox.settings, keychain: sandbox.keychain, file: sandbox.file) { _, _ in }

        _ = await importer.importAvailable()

        let secret = sandbox.keychain.string(service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
        #expect(secret == "bootstrap-s3cr3t")
        let stored = UserDefaults(suiteName: sandbox.suiteName)?.dictionaryRepresentation().description ?? ""
        #expect(!stored.contains("bootstrap-s3cr3t"))
        #expect(!FileManager.default.fileExists(atPath: sandbox.file.path))
    }
}
