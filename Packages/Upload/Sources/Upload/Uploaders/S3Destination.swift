import Foundation

/// An S3-compatible bucket: one signed `PUT` per file (up to S3's 5 GB), the key being the folder in the bucket and
/// the rendered name template.
nonisolated struct S3Destination: DestinationUploader {
    let configuration: UploadConfiguration
    let secretKey: String
    let http: UploadHTTP

    private var uploader: S3Uploader {
        S3Uploader(configuration: configuration, secretKey: secretKey, session: http.session)
    }

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        let key = configuration.key(for: path)
        progress(.sending(0, of: payload.byteCount))
        let delegate = UploadTaskDelegate(progress: progress, total: payload.byteCount)
        let link = try await uploader.upload(
            fileAt: payload.fileURL, key: key, contentType: payload.contentType, length: payload.byteCount, delegate: delegate
        )
        return UploadReceipt(link: link, path: path)
    }

    /// Uploads a tiny object under a random key and deletes it again.
    func testConnection() async throws -> String {
        let key = configuration.makeKey(fileName: "oriel-connection-test.txt")
        try await uploader.upload(Data("Oriel connection test".utf8), key: key, contentType: "text/plain")
        try? await uploader.delete(key: key)
        return "Connected: an upload and a delete both worked."
    }
}
