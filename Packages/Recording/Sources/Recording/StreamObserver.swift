import ScreenCaptureKit

/// The stream's delegate. ScreenCaptureKit calls it on its own queue, so it is nonisolated and only forwards the
/// stop into the session's event stream.
final nonisolated class StreamObserver: NSObject, SCStreamDelegate {
    private let events: AsyncStream<RecordingEvent>.Continuation

    init(events: AsyncStream<RecordingEvent>.Continuation) {
        self.events = events
    }

    func stream(_: SCStream, didStopWithError error: any Error) {
        events.yield(.streamStopped(error))
    }
}
