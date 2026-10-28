import AppKit
import OrielCore
import os
import ScreenCaptureKit

/// A scrolling capture while it runs (PLAN §7.3).
///
/// Automatic mode posts synthetic scroll events at the region's centre (Accessibility), waits until two captures in
/// a row are the same so smooth scrolling and lazy loading have settled, and hands each frame to `ScrollStitcher`
/// with the scroll it asked for. Manual mode samples the region while the user scrolls and hands over every frame that
/// has stopped moving. A frame equal to the previous one, Esc, Done, Cancel or the length limit ends it. This is the
/// only place in Capture with a repeating sampling loop; it exists only while a session runs, inside a
/// `ProcessInfo` activity, and stitching happens off the main thread.
final class ScrollingCaptureSession {
    /// Half the region per scroll leaves a wide overlap to match on.
    private static let stepFraction: CGFloat = 0.5
    private static let chunk = 120

    private let region: CGRect
    private let display: SCDisplay
    private let scale: CGFloat
    private let mode: ScrollingMode
    private let direction: ScrollDirection
    private let configuration: ScrollStitcher.Configuration
    private let engine: ScreenshotEngine
    private let cache: ShareableContentCache
    private let log = Log.logger("capture")
    private var excluded: [SCWindow] = []
    private var hud: ScrollingCaptureHUD?
    private var outline: ScrollingRegionFrame?
    private var monitors: [Any] = []
    private var activity: (any NSObjectProtocol)?
    private var isStopping = false
    private var isCancelled = false

    init(
        region: CGRect,
        display: SCDisplay,
        mode: ScrollingMode,
        direction: ScrollDirection,
        maxLength: Int,
        engine: ScreenshotEngine,
        cache: ShareableContentCache
    ) {
        self.region = region
        self.display = display
        scale = max(1, CGFloat(SCContentFilter(display: display, excludingWindows: []).pointPixelScale))
        self.mode = mode
        self.direction = direction
        var configuration = ScrollStitcher.Configuration()
        configuration.maxLength = maxLength
        self.configuration = configuration
        self.engine = engine
        self.cache = cache
    }

    func run() async -> ScrollingCaptureOutcome {
        begin()
        defer { end() }
        do {
            // Fetched after the outline and the HUD appeared, so both are left out of every frame.
            excluded = try await ShareableContentCache.ownWindows(in: cache.current(refresh: true))
            let first = try await captureFrame()
            let space = first.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
                ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let worker = StitchingWorker(direction: direction, configuration: configuration, colorSpace: space)
            guard await worker.start(with: first) else { return .failed("The first frame could not be read.") }
            switch mode {
            case .automatic:
                return try await scrollAutomatically(worker)
            case .manual:
                return try await followManualScrolling(worker, first: first)
            }
        } catch {
            log.error("Scrolling capture failed: \(error.localizedDescription, privacy: .private)")
            return isCancelled ? .cancelled : .failed(error.localizedDescription)
        }
    }

    // MARK: - Modes

    private func scrollAutomatically(_ worker: StitchingWorker) async throws -> ScrollingCaptureOutcome {
        let distance = (direction == .vertical ? region.height : region.width) * Self.stepFraction
        let expected = Int((distance * scale).rounded())
        var sign: Int32 = -1
        var stoppedEarly = false
        CGWarpMouseCursorPosition(CGPoint(x: region.midX, y: region.midY))
        hud?.update("Scrolling…")
        while !isStopping, !isCancelled {
            postScroll(distance, sign: sign)
            try await Task.sleep(for: .milliseconds(80))
            let frame = try await settledFrame(worker)
            switch await worker.add(frame, expectedOffset: expected) {
            case .appended:
                await hud?.update("Scrolling… \(worker.length.formatted()) px")
            case .endReached:
                // A first scroll that moved nothing may have gone the wrong way: try the other way once.
                if sign < 0, await worker.frameCount == 1 {
                    sign = 1
                } else {
                    isStopping = true
                }
            case .limitReached:
                isStopping = true
            case .lowConfidence:
                if await worker.frameCount <= 1 {
                    return .lowConfidence
                }
                stoppedEarly = true
                isStopping = true
            }
        }
        return await outcome(worker, stoppedEarly: stoppedEarly)
    }

    private func followManualScrolling(_ worker: StitchingWorker, first: CGImage) async throws -> ScrollingCaptureOutcome {
        hud?.update("Scroll slowly. Each part is added once it stops moving.")
        var previous = first
        var accepted = first
        while !isStopping, !isCancelled {
            try await Task.sleep(for: .milliseconds(120))
            let frame = try await captureFrame()
            let settled = await worker.matches(previous, frame)
            previous = frame
            guard settled, await !worker.matches(accepted, frame) else { continue }
            switch await worker.add(frame, expectedOffset: nil) {
            case .appended:
                accepted = frame
                await hud?.update("\(worker.length.formatted()) px · keep scrolling, or press Done")
            case .lowConfidence:
                hud?.update("That jump was too big to line up. Scroll back a little, then more slowly.")
            case .limitReached:
                isStopping = true
            case .endReached:
                break
            }
        }
        return await outcome(worker, stoppedEarly: false)
    }

    private func outcome(_ worker: StitchingWorker, stoppedEarly: Bool) async -> ScrollingCaptureOutcome {
        if isCancelled {
            return .cancelled
        }
        guard let image = await worker.finish() else { return .failed("The frames could not be put together.") }
        return .finished(image, scale: scale, stoppedEarly: stoppedEarly)
    }

    // MARK: - Frames and events

    private func captureFrame() async throws -> CGImage {
        try await engine.capture(region, on: display, excluding: excluded)
    }

    /// Captures until two frames in a row are the same, at most about 300 ms (PLAN §7.3, item 4).
    private func settledFrame(_ worker: StitchingWorker) async throws -> CGImage {
        var previous = try await captureFrame()
        let deadline = ContinuousClock.now + .milliseconds(300)
        while ContinuousClock.now < deadline, !isCancelled {
            try await Task.sleep(for: .milliseconds(50))
            let next = try await captureFrame()
            if await worker.matches(previous, next) {
                return next
            }
            previous = next
        }
        return previous
    }

    /// Pixel-unit scroll-wheel events at the region's centre, in chunks apps accept (PLAN §7.3, item 3).
    private func postScroll(_ distance: CGFloat, sign: Int32) {
        let location = CGPoint(x: region.midX, y: region.midY)
        var remaining = Int(distance.rounded())
        let vertical = direction == .vertical
        while remaining > 0 {
            let amount = min(remaining, Self.chunk)
            let delta = Int32(amount) * sign
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: vertical ? 1 : 2,
                wheel1: vertical ? delta : 0,
                wheel2: vertical ? 0 : delta,
                wheel3: 0
            ) else {
                return
            }
            event.location = location
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.post(tap: .cghidEventTap)
            remaining -= amount
        }
    }

    // MARK: - Lifecycle

    private func begin() {
        let outline = ScrollingRegionFrame(region: region)
        outline.show()
        self.outline = outline
        let hud = ScrollingCaptureHUD(
            onDone: { [weak self] in self?.isStopping = true },
            onCancel: { [weak self] in self?.isCancelled = true }
        )
        hud.show(near: region)
        self.hud = hud
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Scrolling capture")
        // Esc anywhere: the global monitor needs Accessibility, the local one covers Oriel's own panels.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == KeyCode.escape {
                self?.isCancelled = true
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == KeyCode.escape else { return event }
            self?.isCancelled = true
            return nil
        }) {
            monitors.append(local)
        }
    }

    private func end() {
        hud?.close()
        outline?.close()
        hud = nil
        outline = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
        cache.invalidate()
    }
}
