import Foundation
import Testing
@testable import Upload

struct SigV4SignerTests {
    /// AWS's published S3 SigV4 example "GET Object" (examplebucket, test.txt, Range bytes=0-9).
    @Test func matchesAWSsPublishedGetObjectExample() throws {
        let signer = SigV4Signer(
            accessKey: "AKIAIOSFODNN7EXAMPLE",
            secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )
        var request = try URLRequest(url: #require(URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")))
        request.httpMethod = "GET"
        request.setValue("bytes=0-9", forHTTPHeaderField: "Range")
        request.setValue(SigV4Signer.emptyPayloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue("20130524T000000Z", forHTTPHeaderField: "x-amz-date")
        let parts = signer.signatureParts(for: request, payloadHash: SigV4Signer.emptyPayloadHash, timestamp: "20130524T000000Z")
        #expect(parts.signedHeaders == "host;range;x-amz-content-sha256;x-amz-date")
        #expect(parts.scope == "20130524/us-east-1/s3/aws4_request")
        #expect(parts.stringToSign.hasSuffix("7344ae5b7ee6c3e7e6b0fe0640412a37625d1fbfff95c48bbb2dc43964946972"))
        #expect(parts.signature == "f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")
    }

    @Test func signAddsTheThreeHeaders() throws {
        let signer = SigV4Signer(accessKey: "AK", secretKey: "SK", region: "auto")
        var request = try URLRequest(url: #require(URL(string: "https://minio.internal/bucket/a%20b.png")))
        request.httpMethod = "PUT"
        signer.sign(&request, payloadHash: SigV4Signer.payloadHash(Data("x".utf8)), date: Date(timeIntervalSince1970: 0))
        #expect(request.value(forHTTPHeaderField: "x-amz-date") == "19700101T000000Z")
        #expect(request.value(forHTTPHeaderField: "x-amz-content-sha256")?.count == 64)
        let authorization = try #require(request.value(forHTTPHeaderField: "Authorization"))
        let expected = "AWS4-HMAC-SHA256 Credential=AK/19700101/auto/s3/aws4_request, "
            + "SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature="
        #expect(authorization.hasPrefix(expected))
    }

    @Test func pathsAndQueriesAreEncodedTheWayS3Expects() throws {
        #expect(SigV4Signer.uriEncode("a b+c/~") == "a%20b%2Bc%2F~")
        let url = try #require(URL(string: "https://h/bucket/folder/a%20b.png?b=2&a=1"))
        #expect(SigV4Signer.canonicalPath(url) == "/bucket/folder/a%20b.png")
        #expect(SigV4Signer.canonicalQuery(url) == "a=1&b=2")
    }
}

struct UploadConfigurationTests {
    @Test func buildsPathAndVirtualHostedURLsAndPublicLinks() {
        var configuration = UploadConfiguration(
            endpoint: "https://minio.internal",
            bucket: "oriel",
            accessKey: "AK",
            publicBaseURL: "https://files.internal/oriel/"
        )
        #expect(configuration.objectURL(key: "shots/a b.png")?.absoluteString == "https://minio.internal/oriel/shots/a%20b.png")
        #expect(configuration.publicURL(key: "shots/a b.png")?.absoluteString == "https://files.internal/oriel/shots/a%20b.png")
        configuration.usesPathStyle = false
        configuration.publicBaseURL = ""
        #expect(configuration.objectURL(key: "k.png")?.absoluteString == "https://oriel.minio.internal/k.png")
        #expect(configuration.publicURL(key: "k.png") == configuration.objectURL(key: "k.png"))
    }

    @Test func keysAreUnguessableAndKeepTheFileName() {
        let configuration = UploadConfiguration(pathPrefix: "/team/")
        let first = configuration.makeKey(fileName: "shot.png")
        let second = configuration.makeKey(fileName: "shot.png")
        #expect(first != second)
        #expect(first.hasPrefix("team/") && first.hasSuffix("/shot.png"))
        #expect(first.split(separator: "/")[1].count == 32)
    }

    @Test func completenessNeedsEndpointBucketAndAccessKey() {
        #expect(!UploadConfiguration().isComplete)
        #expect(UploadConfiguration(endpoint: "https://s3.amazonaws.com", bucket: "b", accessKey: "a").isComplete)
    }
}
