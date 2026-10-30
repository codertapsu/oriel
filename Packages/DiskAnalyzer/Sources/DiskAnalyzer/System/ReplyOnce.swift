import Synchronization

/// Resumes a continuation with the first answer only: an XPC call can both reply and fail.
final nonisolated class ReplyOnce<Value: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<Value, Never>?>

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = Mutex(continuation)
    }

    func give(_ value: Value) {
        continuation.withLock { $0.take() }?.resume(returning: value)
    }
}
