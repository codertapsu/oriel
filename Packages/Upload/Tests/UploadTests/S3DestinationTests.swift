import CryptoKit
import Foundation
import Testing
@testable import Upload

struct S3DestinationTests {
    @Test func theFileIsStreamedWithItsHashSignedAndTheLinkIsPublic() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { _ in .empty(200) }
        let configuration = UploadConfiguration(
            endpoint: server.baseURL, bucket: "oriel", accessKey: "AK", pathPrefix: "team", publicBaseURL: "https://files.example.com/oriel"
        )
        let bytes = Data("PNG bytes".utf8)
        let destination = S3Destination(configuration: configuration, secretKey: "SK", http: server.http)
        let receipt = try await destination.upload(folder.payload(bytes), to: ["8d3f", "Safari.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://files.example.com/oriel/team/8d3f/Safari.png")
        let put = try #require(server.requests.first)
        #expect(put.method == "PUT")
        #expect(put.url.path == "/oriel/team/8d3f/Safari.png")
        #expect(put.body == bytes)
        #expect(put.header("Content-Type") == "image/png")
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(put.header("x-amz-content-sha256") == hash)
        #expect(put.header("Authorization")?.hasPrefix("AWS4-HMAC-SHA256 Credential=AK/") == true)
    }

    @Test func bucketErrorsSayWhatIsWrong() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        func failure(_ code: String, status: Int) async throws -> UploadError? {
            let server = StubServer { _ in .text("<Error><Code>\(code)</Code><Message>No.</Message></Error>", status: status) }
            let destination = S3Destination(
                configuration: UploadConfiguration(endpoint: server.baseURL, bucket: "b", accessKey: "AK"), secretKey: "SK",
                http: server.http
            )
            do {
                _ = try await destination.upload(folder.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
                return nil
            } catch {
                return UploadError.from(error)
            }
        }
        #expect(try await failure("NoSuchBucket", status: 404) == .notFound("The bucket doesn't exist at that endpoint."))
        #expect(try await failure("SignatureDoesNotMatch", status: 403) ==
            .unauthorized("The bucket refused the access key or the secret key."))
        #expect(try await failure("AccessDenied", status: 403) == .forbidden("The access key may not write to this bucket."))
        #expect(try await failure("SlowDown", status: 503) == .server(status: 503, message: "No."))
    }

    @Test func connectionUploadsAndDeletesATinyObject() async throws {
        let server = StubServer { _ in .empty(204) }
        let destination = S3Destination(
            configuration: UploadConfiguration(endpoint: server.baseURL, bucket: "b", accessKey: "AK"), secretKey: "SK", http: server.http
        )
        #expect(try await destination.testConnection() == "Connected: an upload and a delete both worked.")
        #expect(server.requests.map(\.method) == ["PUT", "DELETE"])
        #expect(server.requests.first?.url.lastPathComponent == "oriel-connection-test.txt")
    }
}
