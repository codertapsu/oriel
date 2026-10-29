import AppKit
import Foundation

/// Everything one running recording owns, from a successful start until it is saved.
struct ActiveRecording {
    let session: RecordingSession
    let controlBar: RecordingControlBar
    let overlays: RecordingOverlays
    let options: RecordingOptions
    let storage: RecordingStorage
    /// Where the segment files are written.
    let scratchFolder: URL
    let startedAt: Date
    /// The screen being recorded, for the finished-recording panel.
    let screen: NSScreen?
    /// The movie's frame size in pixels.
    let videoSize: CGSize
    /// The clicks seen so far, for Auto Zoom; nil when they are not kept.
    var clickLog: ClickLog?
}
