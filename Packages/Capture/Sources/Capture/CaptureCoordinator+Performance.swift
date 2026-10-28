import OrielCore

/// The capture-to-overlay budget (PLAN §9, §13.3), for `oriel debug perf-capture` and scripts/perf-capture.sh.
public extension CaptureCoordinator {
    /// Presents the area overlay `runs` times the way Capture Area does, cancelling each one as soon as it is on
    /// screen, and returns how long each took: the span of the "Capture to overlay" signpost, from fetching the
    /// shareable content to the overlay's windows being ordered in.
    func measureOverlayLatency(runs: Int) async throws -> [Duration] {
        guard !isBusy else { throw CaptureError.failed("Another capture is running.") }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording() else { throw CaptureError.screenRecordingDenied }
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0 ..< runs {
            let start = clock.now
            let interval = signposter.beginInterval("Capture to overlay")
            let screens = try await prepareSelection(keepsHDR: keepsHDR)
            var configuration = OverlayConfiguration(mode: .area)
            configuration.showsMagnifier = settings[CaptureSettings.showsMagnifier]
            let overlay = FreezeFrameOverlay(backdrops: screens.backdrops, windows: screens.windows, configuration: configuration)
            overlay.onPresented = { [signposter, weak overlay] in
                signposter.endInterval("Capture to overlay", interval)
                durations.append(start.duration(to: clock.now))
                overlay?.cancel()
            }
            _ = await overlay.run()
        }
        return durations
    }
}
