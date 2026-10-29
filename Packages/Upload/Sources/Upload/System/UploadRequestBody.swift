import Foundation

/// What a request sends after its headers: nothing more (or its own `httpBody`), a file streamed from disk, or bytes
/// in memory such as one chunk of a large upload.
nonisolated enum UploadRequestBody: Sendable {
    case none
    case file(URL)
    case data(Data)
}
