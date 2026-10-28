import CoreGraphics

/// Captures single windows. `ScreenCaptureKitCapturer` is the real one; tests count calls with a fake.
nonisolated protocol WindowCapturing: Sendable {
    /// Refreshes the cached shareable content when `windowIDs` holds windows it has not seen.
    func prepare(windowIDs: Set<UInt32>) async
    /// The window's contents at `pixelSize`, or nil (no permission, the window is gone or minimized).
    func capture(windowID: UInt32, pixelSize: CGSize) async -> CGImage?
}
