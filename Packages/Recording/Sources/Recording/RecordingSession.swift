import Foundation
import OrielCore
import os
import ScreenCaptureKit

/// One recording's `SCStream`, its segment files and the elapsed-time timer (PLAN §7.4).
///
/// The stream runs from start to stop. A pause removes the segment's `SCRecordingOutput`, which finalizes its file;
/// a resume adds a new output for the next file. The repeating timer that drives the control bar's clock lives
/// here, the one place Recording may poll (CLAUDE.md rule 3), and runs only while frames are being recorded.
final class RecordingSession {
    /// How often the control bar's clock is refreshed while recording.
    static let tickInterval: TimeInterval = 0.5
    /// How long `finish()` waits for the segment outputs to report that their files are complete.
    static let settleTimeout: Duration = .seconds(10)

    /// Called with the elapsed time on every tick and after a pause or resume.
    var onTick: ((Duration) -> Void)?
    /// Called at most once when capture ends by itself: the user or the system stopped it, the disk filled up,
    /// the display went away, or the open segment failed. The coordinator then finishes the recording.
    var onInterruption: ((any Error) -> Void)?

    private(set) var ledger: SegmentLedger
    private let codec: VideoCodec
    private let clock = ContinuousClock()
    private let events: AsyncStream<RecordingEvent>
    private let eventSink: AsyncStream<RecordingEvent>.Continuation
    private var stream: SCStream?
    private var streamObserver: StreamObserver?
    private var output: SCRecordingOutput?
    /// Recording outputs do not retain their delegates.
    private var outputObservers: [Int: RecordingOutputObserver] = [:]
    private var eventTask: Task<Void, Never>?
    private var ticker: Timer?
    private var activity: (any NSObjectProtocol)?
    private var settleWaiters: [CheckedContinuation<Void, Never>] = []
    private var isFinishing = false
    private var didReportInterruption = false
    private let log = Log.logger("recording")

    init(directory: URL, codec: VideoCodec) {
        ledger = SegmentLedger(directory: directory)
        self.codec = codec
        (events, eventSink) = AsyncStream.makeStream(of: RecordingEvent.self)
    }

    /// How long frames have been recorded, pauses excluded.
    var elapsed: Duration {
        ledger.elapsed(at: clock.now)
    }

    /// Starts capture into the first segment. On failure everything is torn down again.
    func start(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        // The display too: a long, hands-off recording would otherwise end up recording a dark screen.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled],
            reason: "Oriel is recording the screen"
        )
        let observer = StreamObserver(events: eventSink)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: observer)
        self.stream = stream
        streamObserver = observer
        listen()
        do {
            try openSegment(on: stream)
            try await stream.startCapture()
        } catch {
            tearDown()
            throw error
        }
        startTicker()
    }

    /// Finalizes the current segment; the stream keeps running so that resuming is instant.
    func pause() throws {
        guard let stream, let output, ledger.openSegment != nil else { return }
        try stream.removeRecordingOutput(output)
        self.output = nil
        ledger.endSegment(at: clock.now)
        stopTicker()
        onTick?(elapsed)
    }

    /// Opens the next segment.
    func resume() throws {
        guard let stream, ledger.openSegment == nil, !isFinishing else { return }
        try openSegment(on: stream)
        startTicker()
    }

    /// Finalizes the open segment, stops capture, waits until every segment file is complete (or the timeout
    /// passes), and returns the complete files in recording order.
    func finish() async -> [URL] {
        guard !isFinishing else { return ledger.finishedURLs }
        isFinishing = true
        stopTicker()
        if let stream {
            // The last segment is finalized the way a pause finalizes one, by removing its output, so every
            // segment file ends through the same path; stopping the stream would also end it.
            if let output {
                do {
                    try stream.removeRecordingOutput(output)
                } catch {
                    log.notice("removing the last output failed: \(error.localizedDescription, privacy: .public)")
                }
                self.output = nil
            }
            ledger.endSegment(at: clock.now)
            do {
                try await stream.stopCapture()
            } catch {
                // The system already stopped a stream it reported through the delegate.
                log.debug("stopCapture: \(error.localizedDescription, privacy: .public)")
            }
        }
        await waitUntilSettled()
        tearDown()
        return ledger.finishedURLs
    }

    private func openSegment(on stream: SCStream) throws {
        guard let segment = ledger.beginSegment(at: clock.now) else { return }
        let observer = RecordingOutputObserver(index: segment.index, events: eventSink)
        let configuration = StreamConfigurationFactory.output(url: segment.url, codec: codec)
        let output = SCRecordingOutput(configuration: configuration, delegate: observer)
        do {
            try stream.addRecordingOutput(output)
        } catch {
            ledger.endSegment(at: clock.now)
            ledger.markFailed(segment.index, reason: error.localizedDescription)
            throw error
        }
        outputObservers[segment.index] = observer
        self.output = output
        log.info("segment \(segment.index) opened at \(segment.url.path, privacy: .private)")
    }

    private func listen() {
        let events = events
        eventTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: RecordingEvent) {
        switch event {
        case let .segmentStarted(index):
            ledger.markStarted(index)
        case let .segmentFinished(index):
            ledger.markFinished(index)
            log.info("segment \(index) finished")
        case let .segmentFailed(index, error):
            log.error("segment \(index) failed: \(error.localizedDescription, privacy: .public)")
            let wasOpen = ledger.openSegment?.index == index
            ledger.markFailed(index, reason: error.localizedDescription)
            if wasOpen {
                interrupt(error)
            }
        case let .streamStopped(error):
            log.notice("the stream stopped: \(error.localizedDescription, privacy: .public)")
            interrupt(error)
        }
        if ledger.isSettled {
            resumeSettleWaiters()
        }
    }

    private func interrupt(_ error: any Error) {
        guard !isFinishing, !didReportInterruption else { return }
        didReportInterruption = true
        onInterruption?(error)
    }

    private func waitUntilSettled() async {
        guard !ledger.isSettled else { return }
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.settleTimeout)
            guard !Task.isCancelled else { return }
            self?.giveUpWaiting()
        }
        await withCheckedContinuation { settleWaiters.append($0) }
        timeout.cancel()
    }

    private func giveUpWaiting() {
        log.error("segment outputs did not finish within \(Self.settleTimeout, privacy: .public)")
        ledger.settleRemaining { FileManager.default.fileExists(atPath: $0.path) }
        resumeSettleWaiters()
    }

    private func resumeSettleWaiters() {
        let waiters = settleWaiters
        settleWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = Self.tickInterval / 5
        // Common modes, so the clock keeps running while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        onTick?(elapsed)
    }

    private func tearDown() {
        stopTicker()
        eventSink.finish()
        eventTask = nil
        stream = nil
        streamObserver = nil
        output = nil
        outputObservers.removeAll()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        resumeSettleWaiters()
    }
}
