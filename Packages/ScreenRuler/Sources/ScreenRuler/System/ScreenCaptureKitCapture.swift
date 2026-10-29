import CoreGraphics
import Foundation
import OrielCore
import os
import ScreenCaptureKit

/// The still pictures, through ScreenCaptureKit (`SCScreenshotManager`, as Capture takes its freeze frames), once when
/// the ruler opens. Every window of Oriel's is left out, so the ruler never measures its own lines. Needs Screen
/// Recording; the overlay checks it first and never asks for it unprompted.
final class ScreenCaptureKitCapture: DisplayCapturing {
    private let log = Log.logger("screen-ruler")

    func capture(_ displays: [RulerDisplay]) async throws -> [CGDirectDisplayID: CGImage] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let pid = ProcessInfo.processInfo.processIdentifier
        let oriel = content.applications.filter { $0.processID == pid }
        let wanted = Set(displays.map(\.id))
        var tasks: [(CGDirectDisplayID, Task<CGImage?, any Error>)] = []
        for display in content.displays where wanted.contains(display.displayID) {
            let filter = SCContentFilter(display: display, excludingApplications: oriel, exceptingWindows: [])
            let scale = max(1, CGFloat(filter.pointPixelScale))
            let configuration = SCScreenshotConfiguration()
            configuration.width = Int((display.frame.width * scale).rounded())
            configuration.height = Int((display.frame.height * scale).rounded())
            configuration.showsCursor = false
            configuration.dynamicRange = .sdr
            tasks.append((display.displayID, Task {
                try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration).sdrImage
            }))
        }
        var images: [CGDirectDisplayID: CGImage] = [:]
        for (id, task) in tasks {
            do {
                images[id] = try await task.value
            } catch {
                log.error("Display \(id, privacy: .public) could not be captured: \(error.localizedDescription, privacy: .public)")
            }
        }
        return images
    }
}
