import CoreGraphics
import OrielCore
import os
import ScreenCaptureKit

/// Window captures through ScreenCaptureKit (PLAN §7.1.7): `SCScreenshotManager.captureImage` with a
/// `SCContentFilter(desktopIndependentWindow:)` at the requested pixel size, without the cursor or shadow.
///
/// `SCShareableContent` is fetched only when the switcher shows windows it has not seen, because every fetch
/// and capture costs `tccd` work. Nothing is captured without Screen Recording: the switcher then shows app
/// icons and titles, and never asks for the permission itself.
actor ScreenCaptureKitCapturer: WindowCapturing {
    private var windows: [UInt32: SCWindow] = [:]
    private var hasContent = false
    private let log = Log.logger("switcher")

    func prepare(windowIDs: Set<UInt32>) async {
        guard CGPreflightScreenCaptureAccess() else {
            windows.removeAll()
            hasContent = false
            return
        }
        guard !hasContent || !windowIDs.isSubset(of: windows.keys) else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            var map: [UInt32: SCWindow] = [:]
            for window in content.windows {
                map[window.windowID] = window
            }
            windows = map
            hasContent = true
        } catch {
            log.error("shareable content failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func capture(windowID: UInt32, pixelSize: CGSize) async -> CGImage? {
        guard let window = windows[windowID], pixelSize.width >= 1, pixelSize.height >= 1 else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(pixelSize.width.rounded())
        configuration.height = Int(pixelSize.height.rounded())
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            // Minimized windows and windows that just closed cannot be captured; the tile keeps its icon.
            return nil
        }
    }
}
