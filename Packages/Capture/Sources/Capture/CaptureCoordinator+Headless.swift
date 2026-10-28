import CoreGraphics
import OrielCore
import ScreenCaptureKit

/// Headless captures for the CLI (`oriel capture area --rect …`): no UI, no prompts, no after-capture action. They
/// reuse the cached shareable content unless it is stale, and never ask for a permission.
public extension CaptureCoordinator {
    /// `rect` (global CoreGraphics points) from the display that shows most of it, clipped to that display and
    /// cropped in pixels at its scale: a 400 × 300 rect on a 2× display is 800 × 600 pixels.
    func captureRect(_ rect: CGRect) async throws -> CaptureResult {
        try requireScreenRecording()
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { throw CaptureError.emptyArea }
        let content = try await cache.current()
        let frames = content.displays.map { DisplayFrame(id: $0.displayID, frame: $0.frame, scale: 1) }
        guard let target = CaptureGeometry.display(for: rect, among: frames),
              let display = content.displays.first(where: { $0.displayID == target.id })
        else {
            throw CaptureError.emptyArea
        }
        let frozen = try await engine.capture(display, excluding: ShareableContentCache.ownWindows(in: content), options: .init())
        return try crop(rect, from: frozen, windows: [], kind: .area, intent: .capture).result
    }

    /// One display at native resolution; nil means the main display.
    func captureScreen(displayID: CGDirectDisplayID?) async throws -> CaptureResult {
        try requireScreenRecording()
        let content = try await cache.current()
        let id = displayID ?? CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.displayNotFound }
        let frozen = try await engine.capture(display, excluding: ShareableContentCache.ownWindows(in: content), options: .init())
        return CaptureResult(image: frozen.image, kind: .screen, rect: frozen.display.frame, scale: frozen.display.scale)
    }

    /// One on-screen window by itself (`SCContentFilter(desktopIndependentWindow:)`), with its shadow when that is on.
    func captureWindow(windowID: CGWindowID) async throws -> CaptureResult {
        try requireScreenRecording()
        var content = try await cache.current()
        if !content.windows.contains(where: { $0.windowID == windowID }) {
            content = try await cache.current(refresh: true)
        }
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound(windowID)
        }
        let shot = try await engine.capture(window: window, shadow: settings[CaptureSettings.windowShadow], keepsHDR: false)
        return CaptureResult(
            image: shot.image,
            kind: .window,
            rect: window.frame,
            scale: shot.scale,
            windowTitle: window.title,
            appName: window.owningApplication?.applicationName
        )
    }

    private func requireScreenRecording() throws {
        guard permissions.status(of: .screenRecording) == .granted else { throw CaptureError.screenRecordingDenied }
    }
}
