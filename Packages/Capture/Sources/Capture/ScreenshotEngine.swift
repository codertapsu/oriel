import CoreGraphics
import OrielCore
import os
import ScreenCaptureKit

/// The ScreenCaptureKit captures (PLAN §7.2): every display at once for the freeze-frame overlay, one window by
/// itself, or one region for scrolling capture. Oriel's own windows are always left out.
final class ScreenshotEngine {
    struct Options {
        var showsCursor = false
        /// Also ask for the HDR image (`SCScreenshotConfiguration.dynamicRange`, macOS 26).
        var keepsHDR = false
    }

    private let log = Log.logger("capture")

    /// Captures `displays` concurrently, each at its native pixel size through
    /// `SCContentFilter(display:excludingWindows:)`. A display that fails is logged and left out.
    func freeze(_ displays: [SCDisplay], excluding excluded: [SCWindow], options: Options) async -> [FrozenDisplay] {
        var tasks: [Task<FrozenDisplay, any Error>] = []
        for display in displays {
            let filter = SCContentFilter(display: display, excludingWindows: excluded)
            let frame = Self.frame(of: display, filter: filter)
            let configuration = Self.configuration(size: frame.frame.size, scale: frame.scale, options: options)
            tasks.append(Task {
                let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
                guard let image = output.sdrImage ?? output.hdrImage else {
                    throw CaptureError.failed("ScreenCaptureKit returned no image for display \(frame.id).")
                }
                return FrozenDisplay(display: frame, image: image, hdrImage: options.keepsHDR ? output.hdrImage : nil)
            })
        }
        var frozen: [FrozenDisplay] = []
        for task in tasks {
            do {
                try await frozen.append(task.value)
            } catch {
                log.error("Display capture failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return frozen
    }

    /// One display, for headless captures.
    func capture(_ display: SCDisplay, excluding excluded: [SCWindow], options: Options) async throws -> FrozenDisplay {
        guard let frozen = await freeze([display], excluding: excluded, options: options).first else {
            throw CaptureError.failed("Display \(display.displayID) could not be captured.")
        }
        return frozen
    }

    /// The window by itself through `SCContentFilter(desktopIndependentWindow:)`, so whatever covers it is not in the
    /// picture; with its shadow (on a transparent background) when `shadow` is on.
    func capture(window: SCWindow, shadow: Bool, keepsHDR: Bool) async throws -> (image: CGImage, hdrImage: CGImage?, scale: CGFloat) {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = false
        configuration.ignoreShadows = !shadow
        configuration.dynamicRange = keepsHDR ? .bothSDRAndHDR : .sdr
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        guard let image = output.sdrImage ?? output.hdrImage else { throw CaptureError.windowNotFound(window.windowID) }
        return (image, keepsHDR ? output.hdrImage : nil, Self.scale(of: filter))
    }

    /// `rect` (global points, inside `display`) at native resolution, for the frames of a scrolling capture.
    func capture(_ rect: CGRect, on display: SCDisplay, excluding excluded: [SCWindow]) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let local = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        let configuration = Self.configuration(size: local.size, scale: Self.scale(of: filter), options: Options())
        configuration.sourceRect = local
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        guard let image = output.sdrImage else { throw CaptureError.failed("ScreenCaptureKit returned no image.") }
        return image
    }

    /// Where `display` is and its pixels per point, without capturing it (a live selection needs no pictures).
    static func frame(of display: SCDisplay, filter: SCContentFilter? = nil) -> DisplayFrame {
        let filter = filter ?? SCContentFilter(display: display, excludingWindows: [])
        return DisplayFrame(id: display.displayID, frame: display.frame, scale: scale(of: filter))
    }

    private static func configuration(size: CGSize, scale: CGFloat, options: Options) -> SCScreenshotConfiguration {
        let configuration = SCScreenshotConfiguration()
        configuration.width = Int((size.width * scale).rounded())
        configuration.height = Int((size.height * scale).rounded())
        configuration.showsCursor = options.showsCursor
        configuration.dynamicRange = options.keepsHDR ? .bothSDRAndHDR : .sdr
        return configuration
    }

    private static func scale(of filter: SCContentFilter) -> CGFloat {
        max(1, CGFloat(filter.pointPixelScale))
    }
}
