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

    /// Adds a frame output, for the camera background effect (PLAN §17). Returns whether the session took it.
    @discardableResult
    func attach(_ output: AVCaptureVideoDataOutput) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }

    /// Removes a frame output added with `attach(_:)`, on the session's queue.
    func detach(_ output: AVCaptureVideoDataOutput) {
        nonisolated(unsafe) let output = output
        queue.async {
            self.session.beginConfiguration()
            self.session.removeOutput(output)
            self.session.commitConfiguration()
        }
    }

    func start() {
        queue.async { self.session.startRunning() }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }
}
