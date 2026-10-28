import AVFoundation

/// Runs the camera behind the bubble. `AVCaptureSession.startRunning()` and `stopRunning()` block until the
/// camera has started or stopped, so they run on a private serial queue, never on the main thread.
///
/// `@unchecked Sendable`: the session is configured once before `start()`, and afterwards only started and stopped
/// on `queue`; the preview layer reads it on the main thread, which AVFoundation supports.
final nonisolated class CameraCaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.codertapsu.oriel.recording.camera", qos: .userInitiated)

    /// Makes `device` the session's input. Throws when the camera cannot be opened.
    func configure(device: AVCaptureDevice) throws {
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        session.sessionPreset = .high
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
        guard !session.inputs.isEmpty else {
            throw RecordingError.streamFailed("The camera cannot be used.")
        }
    }

    func start() {
        queue.async { self.session.startRunning() }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }
}
