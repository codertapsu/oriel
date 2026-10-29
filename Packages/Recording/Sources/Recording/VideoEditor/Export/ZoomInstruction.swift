import AVFoundation
import ImageIO

/// The one instruction of a zoom composition (PLAN §17): it carries the zoom plan and the frame geometry to
/// `ZoomCompositor`, which AVFoundation creates itself and can reach only through its instructions.
///
/// Immutable, so AVFoundation's rendering threads may read it.
final nonisolated class ZoomInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    /// The video track to read frames from.
    let trackID: CMPersistentTrackID
    let plan: ZoomPlan
    /// The frame size as shown, with the track's rotation applied.
    let sourceSize: CGSize
    /// How stored frames are turned upright.
    let orientation: CGImagePropertyOrientation

    init(
        timeRange: CMTimeRange,
        trackID: CMPersistentTrackID,
        plan: ZoomPlan,
        sourceSize: CGSize,
        orientation: CGImagePropertyOrientation
    ) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.plan = plan
        self.sourceSize = sourceSize
        self.orientation = orientation
    }

    /// Frames differ over time only while something is zoomed; without a zoom, AVFoundation may reuse a frame.
    var containsTweening: Bool {
        !plan.isEmpty
    }

    var requiredSourceTrackIDs: [NSValue]? {
        [NSNumber(value: trackID)]
    }
}
