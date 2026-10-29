import Foundation
import Synchronization

/// One request's delegate: reports the bytes sent (at most ten times a second, so the main thread is not flooded)
/// and answers a WebDAV server's Basic or Digest challenge with the destination's credential (`WebDAVChallenge`).
///
/// `offset` and `total` place the request in a larger upload made of several requests, such as Dropbox and Google
/// Drive chunks, so the progress bar runs once from start to end.
final nonisolated class UploadTaskDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private struct State {
        var lastReport: ContinuousClock.Instant?
        var refusedCredential = false
    }

    private let progress: UploadProgressHandler?
    private let offset: Int64
    private let total: Int64?
    private let credential: URLCredential?
    private let state = Mutex(State())

    init(progress: UploadProgressHandler?, offset: Int64 = 0, total: Int64? = nil, credential: URLCredential? = nil) {
        self.progress = progress
        self.offset = offset
        self.total = total
        self.credential = credential
    }

    /// Whether the server turned the credential down, so the error is "wrong password" rather than "cancelled".
    var refusedCredential: Bool {
        state.withLock { $0.refusedCredential }
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let progress else { return }
        let now = ContinuousClock.now
        let expected = total ?? (totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil)
        let finished = totalBytesExpectedToSend > 0 && totalBytesSent >= totalBytesExpectedToSend
        let due = state.withLock { state -> Bool in
            if !finished, let last = state.lastReport, now - last < .milliseconds(100) {
                return false
            }
            state.lastReport = now
            return true
        }
        if due {
            progress(.sending(offset + totalBytesSent, of: expected))
        }
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let answer = WebDAVChallenge.answer(
            method: challenge.protectionSpace.authenticationMethod,
            previousFailures: challenge.previousFailureCount,
            hasCredential: credential != nil
        )
        switch answer {
        case .useCredential:
            return (.useCredential, credential)
        case .performDefault:
            return (.performDefaultHandling, nil)
        case .refuse:
            state.withLock { $0.refusedCredential = true }
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}
