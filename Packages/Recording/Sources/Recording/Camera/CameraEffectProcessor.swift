import AVFoundation
import CoreGraphics
import OrielCore
import os
import Synchronization

/// Runs the camera background effect on the bubble's camera (PLAN §17): an `AVCaptureVideoDataOutput` hands every
/// frame to `CameraBackgroundRenderer` on a private queue, and the newest picture goes to the bubble on the main
/// thread. Frames that arrive while one is still being drawn are dropped, so a busy Mac shows fewer frames rather
/// than late ones.
///
/// The effect steps aside while macOS's own Portrait or background replacement effect is on for the camera (the
/// picture is already treated), and stops for good when the governor says so; the bubble then shows the camera
/// as it is. `@unchecked Sendable`: everything mutable is used on `queue` only, apart from the mailbox's mutex.
final nonisolated class CameraEffectProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// The output to add to the bubble's capture session.
    let output = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "com.codertapsu.oriel.recording.camera-effect", qos: .userInitiated)

    private let device: AVCaptureDevice
    private let renderer: CameraBackgroundRenderer
    private let mailbox: Mailbox
    private var frames = 0
    private var isStopped = false
    private var stepsAside = false
    /// Whether the bubble was last told to show the camera as it is.
    private var showsCamera = false
    private let log = Log.logger("recording")

    /// Called on the main thread once the effect has stopped for good, so its output can leave the session.
    private let onStop: @MainActor @Sendable (CameraEffectProcessor) -> Void

    /// `outputSize` is the bubble's size in pixels. `deliver` is called on the main thread with each picture, or
    /// with nil when the bubble should show the camera as it is.
    init(
        device: AVCaptureDevice,
        background: CameraBackground,
        outputSize: CGSize,
        deliver: @escaping @MainActor @Sendable (CGImage?) -> Void,
        onStop: @escaping @MainActor @Sendable (CameraEffectProcessor) -> Void
    ) {
        self.device = device
        self.onStop = onStop
        renderer = CameraBackgroundRenderer(background: background, outputSize: outputSize)
        mailbox = Mailbox(deliver: deliver)
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        // BGRA at the camera's own size: Vision scales frames down itself, and the renderer fits them to the bubble
        // before anything else. The camera is not asked to scale, since a size whose aspect ratio is off by a pixel
        // is refused with an exception.
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        guard !isStopped, let frame = sampleBuffer.imageBuffer else { return }
        frames += 1
        if frames % 30 == 1 {
            let process = ProcessInfo.processInfo
            renderer.observe(thermalState: process.thermalState, lowPowerMode: process.isLowPowerModeEnabled)
            stepsAside = systemEffectIsActive
        }
        if stepsAside {
            if !showsCamera {
                showsCamera = true
                mailbox.post(nil)
            }
            return
        }
        guard let picture = renderer.render(frame, time: sampleBuffer.presentationTimeStamp.seconds) else {
            stop()
            return
        }
        showsCamera = false
        mailbox.post(picture)
    }

    /// Whether macOS already blurs or replaces the background for this camera.
    private var systemEffectIsActive: Bool {
        device.isPortraitEffectActive || device.isBackgroundReplacementActive
    }

    private func stop() {
        isStopped = true
        let reason = renderer.stopReason ?? "it could not run"
        log.notice("the camera background effect stopped: \(reason, privacy: .public)")
        output.setSampleBufferDelegate(nil, queue: nil)
        mailbox.post(nil)
        let onStop = onStop
        Task { @MainActor [self] in
            onStop(self)
        }
    }

    /// Holds the newest picture and hands it to the main thread, one delivery at a time.
    private final class Mailbox: Sendable {
        private struct State {
            var picture: CGImage?
            var isScheduled = false
        }

        private let state = Mutex(State())
        private let deliver: @MainActor @Sendable (CGImage?) -> Void

        init(deliver: @escaping @MainActor @Sendable (CGImage?) -> Void) {
            self.deliver = deliver
        }

        func post(_ picture: CGImage?) {
            let schedules = state.withLock { state in
                state.picture = picture
                defer { state.isScheduled = true }
                return !state.isScheduled
            }
            guard schedules else { return }
            Task { @MainActor [self] in
                let picture = state.withLock { state in
                    state.isScheduled = false
                    return state.picture
                }
                deliver(picture)
            }
        }
    }
}
