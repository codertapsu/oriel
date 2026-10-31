import AppKit
@testable import Capture
import OrielTestSupport
import ScreenCaptureKit
import Testing

/// Captures leave Oriel's overlays out (checklist, Phase 2: "Window capture excludes our overlays"). The test process
/// stands in for Oriel: it shows a green window with a magenta overlay panel over its middle, then captures the window
/// by itself and the display without the process's own windows, as Capture Window and the freeze do. Runs only with
/// ORIEL_TCC_TESTS=1 on a Mac whose test runner holds Screen Recording; it shows two windows for about a second.
@MainActor
struct OverlayExclusionTCCTests {
    private static let green = (red: 0, green: 255, blue: 0)
    private static let magenta = (red: 255, green: 0, blue: 255)

    private func window(_ frame: CGRect, color: NSColor, level: NSWindow.Level, panel: Bool) -> NSWindow {
        let window = panel
            ? NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            : NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = level
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = color
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        return window
    }

    /// The share of pixels in `rect` (pixels, top-left origin) within 24 levels of `color`.
    private func share(of color: (red: Int, green: Int, blue: Int), in image: CGImage, rect: CGRect) throws -> Double {
        let pixels = try #require(Snapshot.rgba(image))
        let area = rect.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height)).integral
        var matching = 0
        for y in Int(area.minY) ..< Int(area.maxY) {
            for x in Int(area.minX) ..< Int(area.maxX) {
                let index = (y * image.width + x) * 4
                let close = abs(Int(pixels[index]) - color.red) < 24 && abs(Int(pixels[index + 1]) - color.green) < 24
                    && abs(Int(pixels[index + 2]) - color.blue) < 24
                matching += close ? 1 : 0
            }
        }
        return Double(matching) / max(1, Double(area.width * area.height))
    }

    @Test(.requiresTCC)
    func capturesLeaveOurOverlaysOut() async throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = CGRect(x: screen.frame.midX - 200, y: screen.frame.midY - 150, width: 400, height: 300)
        let target = window(frame, color: NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1), level: .normal, panel: false)
        let overlay = window(
            frame.insetBy(dx: 100, dy: 75),
            color: NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1),
            level: .popUpMenu,
            panel: true
        )
        defer {
            overlay.close()
            target.close()
        }
        try await Task.sleep(for: .milliseconds(500))
        let content = try await ShareableContentCache().current(refresh: true)

        // Capture Window: the window by itself, so the overlay over it is not in the picture.
        let scWindow = try #require(content.windows.first { $0.windowID == CGWindowID(target.windowNumber) })
        let captured = try await ScreenshotEngine().capture(window: scWindow, shadow: false, keepsHDR: false)
        let middle = CGRect(
            x: captured.image.width / 4,
            y: captured.image.height / 4,
            width: captured.image.width / 2,
            height: captured.image.height / 2
        )
        #expect(try share(of: Self.green, in: captured.image, rect: middle) > 0.95)
        #expect(try share(of: Self.magenta, in: captured.image, rect: middle) == 0)

        // The freeze: the display without the process's own windows, so neither shows.
        let display = try #require(content.displays.first { $0.frame.contains(CGPoint(x: frame.midX, y: screen.frame.maxY - frame.midY)) })
        let frozen = try await ScreenshotEngine().capture(
            display,
            excluding: ShareableContentCache.ownWindows(in: content),
            options: .init()
        )
        let scale = frozen.display.scale
        // AppKit's y grows up from the bottom of the first screen; the capture's grows down from the display's top.
        let overlayInDisplay = CGRect(
            x: (overlay.frame.minX - display.frame.minX) * scale,
            y: (screen.frame.maxY - overlay.frame.maxY - display.frame.minY) * scale,
            width: overlay.frame.width * scale,
            height: overlay.frame.height * scale
        )
        #expect(try share(of: Self.magenta, in: frozen.image, rect: overlayInDisplay) < 0.01)
        #expect(try share(of: Self.green, in: frozen.image, rect: overlayInDisplay) < 0.01)
    }
}
