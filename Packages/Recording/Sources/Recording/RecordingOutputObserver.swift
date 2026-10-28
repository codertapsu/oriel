import ScreenCaptureKit

/// The delegate of one segment's `SCRecordingOutput`. ScreenCaptureKit calls it on its own queue, so it is
/// nonisolated and only forwards each callback into the session's event stream, which keeps them in order.
final nonisolated class RecordingOutputObserver: NSObject, SCRecordingOutputDelegate {
    private let index: Int
    private let events: AsyncStream<RecordingEvent>.Continuation

    init(index: Int, events: AsyncStream<RecordingEvent>.Continuation) {
        self.index = index
        self.events = events
    }

    func recordingOutputDidStartRecording(_: SCRecordingOutput) {
        events.yield(.segmentStarted(index))
    }

    func recordingOutput(_: SCRecordingOutput, didFailWithError error: any Error) {
        events.yield(.segmentFailed(index, error))
    }

    func recordingOutputDidFinishRecording(_: SCRecordingOutput) {
        events.yield(.segmentFinished(index))
    }
}
