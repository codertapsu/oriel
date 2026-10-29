import Foundation
import OrielCore
import Testing
@testable import Upload

@MainActor
struct UploadDestinationStoreTests {
    private let legacy = UploadConfiguration(
        endpoint: "https://minio.internal", region: "eu-1", bucket: "oriel", accessKey: "AK", pathPrefix: "team",
        publicBaseURL: "https://files.internal/oriel", usesPathStyle: true, stripsMetadata: false
    )

    private func legacySecret(_ secrets: InMemorySecrets) -> String? {
        secrets.string(service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
    }

    private func secretKey(_ secrets: InMemorySecrets, of id: UUID) -> String? {
        secrets.string(service: UploadSettings.keychainService, account: UploadSecret.secretKey.account(for: id))
    }

    @Test func everyKindSurvivesARoundTrip() throws {
        let list = UploadDestinationList(destinations: [
            UploadDestination(name: "Bucket", target: .s3(legacy), nameTemplate: "{name}", linkFormat: .markdown, stripsMetadata: false),
            UploadDestination(
                name: "NAS",
                target: .webDAV(WebDAVConfiguration(
                    serverURL: "https://nas",
                    username: "m",
                    folder: "a/b",
                    publicURLTemplate: "https://x/{path}"
                ))
            ),
            UploadDestination(
                name: "Web",
                target: .sftp(SFTPConfiguration(host: "web1", port: 2222, username: "d", remoteFolder: "/srv", identityFile: "~/.ssh/k"))
            ),
            UploadDestination(
                name: "Share",
                target: .sharedFolder(SharedFolderConfiguration(path: "/Volumes/S", bookmark: Data([1, 2]), publicURLTemplate: ""))
            ),
            UploadDestination(
                name: "Box",
                target: .dropbox(DropboxConfiguration(appKey: "k", folder: "/O", linkStyle: .download)),
                linkFormat: .html
            ),
            UploadDestination(name: "Drive", target: .googleDrive(GoogleDriveConfiguration(
                clientID: "c.apps.googleusercontent.com", folderID: "F", createdFolderID: "G", sharesPublicly: false, linkStyle: .download,
                access: .everything
            ))),
        ])
        var withDefault = list
        withDefault.makeDefault(list.destinations[2].id)
        let decoded = try JSONDecoder().decode(UploadDestinationList.self, from: JSONEncoder().encode(withDefault))
        #expect(decoded == withDefault)
        #expect(decoded.defaultDestination?.name == "Web")

        let settings = TemporarySettings()
        defer { settings.remove() }
        settings.store[UploadSettings.destinations] = withDefault
        #expect(settings.store[UploadSettings.destinations] == withDefault)
    }

    @Test func missingFieldsTakeTheirDefaultsAndUnknownKindsAreLeftOut() throws {
        let json = #"""
        {"destinations":[
          {"kind":"ftp","name":"From a newer Oriel"},
          {"kind":"webdav","name":"NAS","webdav":{"serverURL":"https://nas.local"}},
          {"kind":"dropbox"}
        ],"defaultDestination":"8B0F2C4E-1D3A-4F5B-9C7D-0E1F2A3B4C5D"}
        """#
        let list = try JSONDecoder().decode(UploadDestinationList.self, from: Data(json.utf8))
        #expect(list.destinations.count == 2)
        let nas = try #require(list.destinations.first)
        #expect(nas.name == "NAS")
        #expect(nas.nameTemplate == UploadNameTemplate.unguessable)
        #expect(nas.linkFormat == .url)
        #expect(nas.stripsMetadata)
        #expect(nas.target == .webDAV(WebDAVConfiguration(serverURL: "https://nas.local", folder: "")))
        #expect(list.destinations[1].nameTemplate == UploadNameTemplate.readable)
        #expect(list.destinations[1].name == "Dropbox")
        // The default was the one left out, so the first takes its place.
        #expect(list.defaultDestination?.id == nas.id)
    }

    @Test func newDestinationsGetNamesOfTheirOwn() {
        var list = UploadDestinationList()
        #expect(list.add(.webDAV).name == "WebDAV")
        #expect(list.add(.webDAV).name == "WebDAV 2")
        #expect(list.add(.s3).name == "S3")
        #expect(list.add(.webDAV).name == "WebDAV 3")
        #expect(list.defaultDestination?.name == "WebDAV")
    }

    @Test func removingADestinationRemovesItsSecretsAndTheDefaultMovesOn() throws {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        let store = UploadDestinationStore(settings: settings.store, secrets: secrets)
        let first = store.add(.s3)
        let second = store.add(.webDAV)
        store.makeDefault(first.id)
        try secrets.setString("s3cr3t", .secretKey, for: first.id)
        try secrets.setString("pw", .password, for: second.id)
        store.remove(first.id)
        #expect(store.destinations.map(\.id) == [second.id])
        #expect(store.defaultDestination?.id == second.id)
        #expect(secrets.accounts == [UploadSecret.password.account(for: second.id)])
    }

    @Test func theSingleS3SettingOfOriel01BecomesTheDefaultDestination() throws {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        settings.store[UploadSettings.configuration] = legacy
        try secrets.setData(Data("s3cr3t".utf8), service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)

        let store = UploadDestinationStore(settings: settings.store, secrets: secrets)

        let destination = try #require(store.destinations.first)
        #expect(store.destinations.count == 1)
        #expect(destination.id == UploadDestinationList.legacyID)
        #expect(destination.name == "minio.internal")
        #expect(destination.target == .s3(legacy))
        #expect(destination.nameTemplate == "{random}/{name}")
        #expect(!destination.stripsMetadata)
        #expect(store.defaultDestination?.id == destination.id)
        #expect(secretKey(secrets, of: destination.id) == "s3cr3t")
        #expect(legacySecret(secrets) == nil)
        #expect(!settings.store.hasValue(UploadSettings.configuration))

        // The same object keys as before: the folder in the bucket, a random folder, the name.
        guard case let .s3(configuration) = destination.target else {
            Issue.record("not an S3 destination")
            return
        }
        #expect(configuration.key(for: ["8d3f", "a.png"]) == "team/8d3f/a.png")

        // Taken in once only.
        let again = UploadDestinationStore(settings: settings.store, secrets: secrets)
        #expect(again.destinations.count == 1)
    }

    @Test func aBootstrapImportUpdatesThatDestination() async throws {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        settings.store[UploadSettings.configuration] = legacy
        let store = UploadDestinationStore(settings: settings.store, secrets: secrets)
        var renamed = try #require(store.destinations.first)
        renamed.name = "Team bucket"
        store.update(renamed)

        // What BootstrapImporter does: the setting, then the secret key.
        var imported = legacy
        imported.endpoint = "https://s3.example.com"
        settings.store[UploadSettings.configuration] = imported
        try secrets.setData(Data("new-secret".utf8), service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
        for _ in 0 ..< 100 where settings.store.hasValue(UploadSettings.configuration) {
            try await Task.sleep(for: .milliseconds(10))
        }

        let destination = try #require(store.destinations.first)
        #expect(store.destinations.count == 1)
        #expect(destination.name == "Team bucket")
        #expect(destination.target == .s3(imported))
        #expect(secretKey(secrets, of: destination.id) == "new-secret")
        #expect(legacySecret(secrets) == nil)
    }

    @Test func anUntouchedSettingIsNotTakenIn() {
        let settings = TemporarySettings()
        defer { settings.remove() }
        settings.store[UploadSettings.configuration] = UploadConfiguration()
        let store = UploadDestinationStore(settings: settings.store, secrets: InMemorySecrets())
        #expect(store.destinations.isEmpty)
        #expect(!settings.store.hasValue(UploadSettings.configuration))
    }

    @Test func theOldDestinationJoinsOthersWithoutTakingTheDefault() {
        let settings = TemporarySettings()
        defer { settings.remove() }
        var list = UploadDestinationList()
        let nas = list.add(.webDAV)
        list.makeDefault(nas.id)
        settings.store[UploadSettings.destinations] = list
        settings.store[UploadSettings.configuration] = legacy
        let store = UploadDestinationStore(settings: settings.store, secrets: InMemorySecrets())
        #expect(store.destinations.map(\.id) == [UploadDestinationList.legacyID, nas.id])
        #expect(store.defaultDestination?.id == nas.id)
    }

    @Test func aLockedKeychainKeepsTheOldSecretKeyForLater() throws {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        settings.store[UploadSettings.configuration] = legacy
        try secrets.setData(Data("s3cr3t".utf8), service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
        secrets.locked = true
        let store = UploadDestinationStore(settings: settings.store, secrets: secrets)
        #expect(store.destinations.count == 1)
        secrets.locked = false
        #expect(legacySecret(secrets) == "s3cr3t")

        _ = UploadDestinationStore(settings: settings.store, secrets: secrets)
        #expect(secretKey(secrets, of: UploadDestinationList.legacyID) == "s3cr3t")
        #expect(legacySecret(secrets) == nil)
    }
}
