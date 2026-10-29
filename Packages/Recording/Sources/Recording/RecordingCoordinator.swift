import AppKit
import OrielCore
import os
import Permissions
import ScreenCaptureKit
import SharedUI
import SwiftUI

/// Screen recording (PLAN §7.4, D8). Each recording is one `SCStream` writing through `SCRecordingOutput`, one
/// file per stretch between pauses; stopping joins the files and opens the finished-recording panel, which plays,
/// trims and exports the movie, and opens it in the video editor (PLAN §17).
///
/// The clicks of a recording are kept next to the movie (`<name>.oriel-clicks.json`) for the editor's Auto Zoom.
///
/// While recording, a control bar shows the time. Oriel's overlays (camera bubble, click rings, keystroke HUD) are
/// recorded; the control bar is excluded from the stream's filter.
public final class RecordingCoordinator {
    /// Where the coordinator is in its life cycle.
    public private(set) var state: RecordingState = .idle {
        didSet {
            if state != oldValue {
                onStateChange?(state)
            }
        }
    }

    /// Whether a recording is starting, running, paused or being saved.
    public var isActive: Bool {
        state != .idle
    }

    /// Called with every saved movie, before the finished-recording panel opens, e.g. to add it to History.
    public var onFinished: ((URL) -> Void)?

    /// Called whenever `state` changes, e.g. to show a recording indicator in the menu bar.
    public var onStateChange: ((RecordingState) -> Void)?

    /// The Recording pane for Settings.
    public var settingsPane: AnyView {
        AnyView(RecordingSettingsView(settings: settings, permissions: permissions))
    }

    let settings: SettingsStore
    private let permissions: PermissionCenter
    /// On-device OCR for reading text off a video frame; nil leaves that out.
    let textRecognizer: (any TextRecognizing)?
    private var current: ActiveRecording?
    private var stopRequested = false
    /// Why capture ended early, shown once the movie is saved.
    private var interruption: String?
    private var panels: [ObjectIdentifier: FinishedRecordingPanel] = [:]
    /// Open video editor windows (PLAN §17).
    var editors: [VideoEditorWindowController] = []
    private let clock = ContinuousClock()
    let log = Log.logger("recording")

    /// Creating the coordinator starts nothing and asks for no permission.
    public init(settings: SettingsStore, permissions: PermissionCenter, textRecognizer: (any TextRecognizing)? = nil) {
        self.settings = settings
        self.permissions = permissions
        self.textRecognizer = textRecognizer
    }

    /// Requests Screen Recording (and the microphone and camera when settings use them), shows the control bar and
    /// the overlays, and starts recording `target`.
    ///
    /// Throws `OrielError.permissionMissing(.screenRecording)` without the grant, or a `RecordingError`. Without
    /// the Microphone or Camera permission it records without them; keystrokes are shown only with Accessibility.
    public func start(_ target: RecordingTarget) async throws {
        guard state == .idle else { throw RecordingError.alreadyRecording }
        state = .starting
        stopRequested = false
        interruption = nil
        do {
            current = try await begin(target)
        } catch {
            state = .idle
            log.error("the recording did not start: \(error.localizedDescription, privacy: .public)")
            throw Self.startError(error)
        }
        state = .recording
        log.info("recording started")
        if stopRequested {
            stopRequested = false
            await stop()
        }
    }

    /// Pauses a running recording or resumes a paused one; does nothing otherwise.
    public func togglePause() async {
        guard let current else { return }
        do {
            switch state {
            case .recording:
                try current.session.pause()
                state = .paused
                current.controlBar.setPaused(true)
            case .paused:
                try current.session.resume()
                state = .recording
                current.controlBar.setPaused(false)
            case .idle, .starting, .finishing:
                return
            }
        } catch {
            log.error("pause or resume failed: \(error.localizedDescription, privacy: .public)")
            if state == .paused {
                Toast.show("The recording could not resume.", symbol: "exclamationmark.triangle")
            }
        }
    }

    /// Stops capture, joins the segments into one movie in the output folder, then shows the finished-recording
    /// panel (play, trim, export GIF, reveal, copy the file). Called while starting, it stops right after the start.
    ///
    /// Returns the saved movie, or its parts when they could not be joined; empty when nothing was saved or
    /// nothing was recording.
    @discardableResult
    public func stop() async -> [URL] {
        switch state {
        case .starting:
            stopRequested = true
            return []
        case .idle, .finishing:
            return []
        case .recording, .paused:
            break
        }
        guard let recording = current else {
            state = .idle
            return []
        }
        state = .finishing
        recording.controlBar.setFinishing()
        let segments = await recording.session.finish()
        recording.overlays.hide()
        let saved = await save(segments, of: recording)
        recording.controlBar.close()
        recording.storage.discard(recording.scratchFolder)
        current = nil
        state = .idle
        present(saved, of: recording)
        return (try? saved.get()) ?? []
    }

    // MARK: Starting

    private func begin(_ target: RecordingTarget) async throws -> ActiveRecording {
        try await requireScreenRecording()
        let (options, features) = await resolveOptions()
        let storage = RecordingStorage(outputFolder: options.outputFolder)
        try storage.prepare()
        let resolved = try await CaptureTargetResolver.resolve(target, in: Self.shareableContent())
        let captureRect = ScreenLocator.cocoaRect(fromCG: resolved.geometry.captureRect)
        let screen = ScreenLocator.screen(for: resolved.display.displayID)
        let controlBar = RecordingControlBar(microphoneOn: options.microphone)
        let overlays = RecordingOverlays()
        overlays.onClick = { [weak self] click in
            self?.logClick(click)
        }
        // On screen before the filter is built, so the control bar's window can be found and excluded.
        controlBar.show(near: captureRect, on: screen)
        overlays.show(features, captureRect: captureRect, on: screen, unrecordedWindows: [controlBar.windowID])
        var scratchFolder: URL?
        do {
            let filter = try await contentFilter(displayID: resolved.display.displayID, excluding: controlBar.windowID)
            let configuration = StreamConfigurationFactory.stream(options: options, geometry: resolved.geometry)
            let folder = try storage.makeScratchFolder()
            scratchFolder = folder
            let session = RecordingSession(directory: folder, codec: options.codec)
            connect(session, to: controlBar)
            try await session.start(filter: filter, configuration: configuration)
            return ActiveRecording(
                session: session,
                controlBar: controlBar,
                overlays: overlays,
                options: options,
                storage: storage,
                scratchFolder: folder,
                startedAt: Date(),
                screen: screen,
                videoSize: CGSize(width: configuration.width, height: configuration.height),
                clickLog: features.clickLog
                    ? ClickLog(area: captureRect, pixelWidth: configuration.width, pixelHeight: configuration.height)
                    : nil
            )
        } catch {
            controlBar.close()
            overlays.hide()
            if let scratchFolder {
                storage.discard(scratchFolder)
            }
            throw error
        }
    }

    private func requireScreenRecording() async throws {
        if permissions.status(of: .screenRecording) == .granted {
            return
        }
        if await permissions.request(.screenRecording) == .granted {
            return
        }
        throw OrielError.permissionMissing(.screenRecording)
    }

    /// The settings for this recording, with the extras the permissions do not allow switched off.
    private func resolveOptions() async -> (RecordingOptions, RecordingFeatures) {
        var options = RecordingOptions(settings: settings)
        options.codec = StreamConfigurationFactory.supportedCodec(options.codec)
        if options.microphone, await !allows(.microphone) {
            log.notice("recording without the microphone: no permission")
            options.microphone = false
        }
        var features = RecordingFeatures(microphone: options.microphone, clickRings: options.clickRings)
        features.clickLog = options.remembersClicks
        if options.cameraBubble {
            features.cameraBubble = await allows(.camera)
            features.cameraBackground = options.cameraBackground
        }
        // A key monitor without Accessibility receives nothing, so the HUD is not shown at all.
        features.keystrokes = options.keystrokes && permissions.status(of: .accessibility) == .granted
        return (options, features)
    }

    private func allows(_ kind: PermissionKind) async -> Bool {
        switch permissions.status(of: kind) {
        case .granted:
            true
        case .denied:
            false
        case .notDetermined:
            await permissions.request(kind) == .granted
        }
    }

    /// The target's display without the control bar. A window that was ordered in a moment ago can be missing from
    /// the first list, so a miss is retried once.
    private func contentFilter(displayID: CGDirectDisplayID, excluding windowID: CGWindowID) async throws -> SCContentFilter {
        var content = try await Self.shareableContent()
        if !content.windows.contains(where: { $0.windowID == windowID }) {
            try await Task.sleep(for: .milliseconds(150))
            content = try await Self.shareableContent()
        }
        let excluded = content.windows.filter { $0.windowID == windowID }
        if excluded.isEmpty {
            log.notice("the control bar is not in the shareable content, so it may be recorded")
        }
        return try SCContentFilter(display: CaptureTargetResolver.find(displayID, in: content), excludingWindows: excluded)
    }

    private func connect(_ session: RecordingSession, to controlBar: RecordingControlBar) {
        session.onTick = { [weak controlBar] elapsed in
            controlBar?.update(elapsed: elapsed)
        }
        session.onInterruption = { [weak self] error in
            Task { await self?.handleInterruption(error) }
        }
        controlBar.onTogglePause = { [weak self] in
            Task { await self?.togglePause() }
        }
        controlBar.onStop = { [weak self] in
            Task { await self?.stop() }
        }
    }

    private static func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// What `start` throws: a refused grant as a missing permission, anything else as a `RecordingError`.
    private static func startError(_ error: any Error) -> any Error {
        if error is OrielError || error is RecordingError || error is CancellationError {
            return error
        }
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.Code.userDeclined.rawValue {
            return OrielError.permissionMissing(.screenRecording)
        }
        return RecordingError.from(error)
    }

    // MARK: Finishing

    /// Capture ended by itself. A stop from the system's screen-sharing menu saves silently; anything else saves
    /// what was recorded and says why it stopped.
    private func handleInterruption(_ error: any Error) async {
        if !RecordingError.isUserStop(error) {
            let reason = RecordingError.from(error).localizedDescription
            interruption = "The recording stopped early. \(reason)"
        }
        switch state {
        case .starting:
            stopRequested = true
        case .recording, .paused:
            await stop()
        case .idle, .finishing:
            break
        }
    }

    private func save(_ segments: [URL], of recording: ActiveRecording) async -> Result<[URL], any Error> {
        do {
            // Measured before joining, which moves or merges the segment files.
            let durations = recording.clickLog == nil ? [:] : await recording.storage.durations(of: segments)
            let movie = try await recording.storage.finalize(segments, startedAt: recording.startedAt)
            if let clicks = recording.clickLog {
                await saveClicks(clicks, durations: durations, of: recording, nextTo: movie)
            }
            return .success([movie])
        } catch {
            log.error("saving the recording failed: \(error.localizedDescription, privacy: .public)")
            guard segments.count > 1 else { return .failure(error) }
            let parts = await recording.storage.salvage(segments, startedAt: recording.startedAt)
            return parts.isEmpty ? .failure(error) : .success(parts)
        }
    }

    /// Keeps a click that happened while frames were being written, on the open segment's clock.
    private func logClick(_ click: ClickMonitor.Click) {
        guard state == .recording, current?.clickLog != nil, let segment = current?.session.ledger.openSegment else { return }
        let offset = (clock.now - segment.openedAt) / .seconds(1)
        current?.clickLog?.record(click.location, button: click.button, segment: segment.index, offset: offset)
    }

    /// Writes the recording's clicks next to the finished movie, on its timeline: each segment starts where the
    /// joined movie has it. A recording without clicks writes nothing.
    private func saveClicks(_ clicks: ClickLog, durations: [URL: Double], of recording: ActiveRecording, nextTo movie: URL) async {
        guard !clicks.entries.isEmpty else { return }
        let order = recording.session.ledger.segments.map { (segment: $0.index, duration: durations[$0.url]) }
        let total = durations.values.reduce(0, +)
        let sidecar = clicks.sidecar(segmentStarts: ClickLog.segmentStarts(durations: order), duration: total)
        do {
            try await sidecar.save(nextTo: movie)
            log.info("saved \(sidecar.clicks.count) clicks for Auto Zoom")
        } catch {
            log.error("the clicks could not be saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func present(_ result: Result<[URL], any Error>, of recording: ActiveRecording) {
        let reason = interruption
        interruption = nil
        switch result {
        case let .success(files):
            for file in files {
                log.info("saved \(file.path, privacy: .private)")
                onFinished?(file)
            }
            if files.count == 1, let movie = files.first {
                showPanel(for: movie, of: recording)
                if let reason {
                    Toast.show(reason, symbol: "exclamationmark.triangle")
                }
            } else {
                NSWorkspace.shared.activateFileViewerSelecting(files)
                Toast.show("The parts could not be joined, so they were saved separately.", symbol: "exclamationmark.triangle")
            }
        case let .failure(error):
            Toast.show(reason ?? error.localizedDescription, symbol: "exclamationmark.triangle")
        }
    }

    private func showPanel(for movie: URL, of recording: ActiveRecording) {
        let panel = FinishedRecordingPanel(
            movie: movie,
            frameRate: recording.options.frameRate,
            videoSize: recording.videoSize,
            settings: settings,
            textRecognizer: textRecognizer
        )
        let key = ObjectIdentifier(panel)
        panel.onClose = { [weak self] in
            self?.panels[key] = nil
        }
        panel.onEdit = { [weak self] movie in
            self?.openVideo(at: movie)
        }
        panels[key] = panel
        panel.show(on: recording.screen)
    }
}
