import Foundation
import Testing
@testable import Upload

struct UploadServiceTests {
    private func service(
        _ secrets: InMemorySecrets,
        runner: FakeProcessRunner = FakeProcessRunner(ProcessResult(status: 0))
    ) -> UploadService {
        UploadService(secrets: secrets, runner: runner, endpoints: .production, makeSession: { StubURLProtocol.makeSession() })
    }

    @Test func aDestinationThatIsNotReadySaysWhatIsMissing() async throws {
        let secrets = InMemorySecrets()
        let service = service(secrets)
        let empty = UploadDestination(name: "Team NAS", target: .webDAV(WebDAVConfiguration()))
        await #expect(throws: UploadError.notConfigured(destination: "Team NAS", missing: "a server address (https://…)")) {
            try await service.checkReady(empty)
        }
        let bucket = UploadDestination(
            name: "Bucket",
            target: .s3(UploadConfiguration(endpoint: "https://s3.example.com", bucket: "b", accessKey: "AK"))
        )
        await #expect(throws: UploadError.missingSecret(destination: "Bucket", secret: "secret key")) {
            try await service.checkReady(bucket)
        }
        try secrets.setString("SK", .secretKey, for: bucket.id)
        try await service.checkReady(bucket)
        let nas = UploadDestination(name: "NAS", target: .webDAV(WebDAVConfiguration(serverURL: "https://nas.local", username: "m")))
        await #expect(throws: UploadError.missingSecret(destination: "NAS", secret: "password")) { try await service.checkReady(nas) }
        let open = UploadDestination(name: "Open", target: .webDAV(WebDAVConfiguration(serverURL: "https://nas.local")))
        try await service.checkReady(open)
        let unsafe = UploadDestination(name: "Web", target: .sftp(SFTPConfiguration(host: "-oProxyCommand=x")))
        await #expect(throws: UploadError.self) { try await service.checkReady(unsafe) }
        secrets.locked = true
        let error = await #expect(throws: UploadError.self) { try await service.checkReady(bucket) }
        guard case .keychain = error else {
            Issue.record("a locked keychain was not reported as one: \(String(describing: error))")
            return
        }
    }

    @Test func theNameTemplateNamesTheUpload() async throws {
        let folder = try TemporaryFolder()
        let target = try TemporaryFolder()
        defer {
            folder.remove()
            target.remove()
        }
        let destination = try UploadDestination(
            name: "Share",
            target: .sharedFolder(SharedFolderConfiguration(path: target.url.path, bookmark: SharedFolderAccess.bookmark(for: target.url))),
            nameTemplate: "{date}/{name} {time}"
        )
        let date = Date(timeIntervalSince1970: 1_793_268_930)
        let receipt = try await service(InMemorySecrets()).upload(
            folder.payload(Data("x".utf8), name: "Start Page"),
            to: destination,
            date: date
        ) { _ in }
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let time = String(format: "%02d.%02d.%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        #expect(receipt.path == [day, "Start Page \(time).png"])
        #expect(FileManager.default.fileExists(atPath: target.url.appending(path: "\(day)/Start Page \(time).png").path))
    }
}
