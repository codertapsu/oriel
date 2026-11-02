#if !APP_STORE
    import ActivityMonitor
    import IPC
#endif
import AppKit
import Capture
import ClipboardHistory
import ColorPicker
import DiskAnalyzer
import Editor
import OCR
import OrielCore
import OrielTranslation
import os
import Permissions
import Recording
import ScreenRuler
import SharedUI
import SwiftUI
import Upload
#if !APP_STORE
    import WindowSwitcher
    import WindowTiling
#endif

/// Owns the feature coordinators — capture, recording, translation, the editor and upload — and the utility modules,
/// and connects them: the Quick Access Overlay's Annotate, Translate and Upload come back here through
/// `CaptureActionHandling`. The shell talks only to this type.
@MainActor
final class FeatureHub: CaptureActionHandling {
    let recognizer = VisionTextRecognizer()
    let capture: CaptureCoordinator
    let recording: RecordingCoordinator
    let translation: TranslationCoordinator
    let editor: EditorLauncher
    let uploads: UploadCoordinator
    #if !APP_STORE
        let switcher = WindowSwitcherModule()
        let activityMonitor = ActivityMonitorModule()
        let windowTiling = WindowTilingModule()
    #endif
    let clipboard = ClipboardHistoryModule()
    let diskAnalyzer = DiskAnalyzerModule()
    let colorPicker = ColorPickerModule()
    let screenRuler = ScreenRulerModule()

    /// Called whenever a recording starts, pauses or ends, so the status item can show it.
    var onRecordingChange: ((Bool) -> Void)?

    private let settings: SettingsStore
    private let keychain: KeychainStore
    private let log = Log.logger("hub")

    init(settings: SettingsStore, permissions: PermissionCenter, keychain: KeychainStore) {
        self.settings = settings
        self.keychain = keychain
        capture = CaptureCoordinator(settings: settings, permissions: permissions, textRecognizer: recognizer)
        recording = RecordingCoordinator(settings: settings, permissions: permissions, textRecognizer: recognizer)
        translation = TranslationCoordinator(settings: settings, keychain: keychain, textRecognizer: recognizer)
        editor = EditorLauncher(settings: settings, textRecognizer: recognizer)
        uploads = UploadCoordinator(settings: settings, keychain: keychain)
        capture.actions = self
        translation.screenCapture = { [weak self] rect in
            guard let self else { throw CancellationError() }
            return try await capture.captureRect(rect).image
        }
        editor.onUpload = { [weak self] image in
            Task { await self?.uploads.upload(image) }
        }
        recording.onStateChange = { [weak self] state in
            self?.onRecordingChange?(state != .idle)
        }
    }

    var textRecognizer: (any TextRecognizing)? {
        recognizer
    }

    /// The tools, in Settings order. The App Store edition has those the sandbox allows (PLAN §19).
    var modules: [any UtilityModule] {
        #if APP_STORE
            [clipboard, diskAnalyzer, colorPicker, screenRuler]
        #else
            [switcher, clipboard, diskAnalyzer, activityMonitor, colorPicker, screenRuler, windowTiling]
        #endif
    }

    /// The commands of the features (PLAN §6.5); the tools' own come through the module registry.
    var commands: [ToolCommand] {
        [instantCaptureCommand] + capture.commands + recording.commands + translation.commands + editor.commands
    }

    var isRecording: Bool {
        recording.isActive
    }

    func isAvailable(_ action: AppAction) -> Bool {
        switch action {
        case .stopRecording: recording.isActive
        default: true
        }
    }

    // MARK: Actions

    func perform(_ action: AppAction) async {
        switch action {
        case .captureArea: await capture.capture(.area)
        case .captureWindow: await capture.capture(.window)
        case .captureScreen: await capture.capture(.screen)
        case .captureScrolling: await capture.capture(.scrolling)
        case .capturePreviousArea: await capture.capture(.previousArea)
        case .captureWithTimer: await capture.capture(.area, delay: capture.timerDelay)
        case .captureAllDisplays: await capture.capture(.allDisplays)
        case .recordArea: await recordArea()
        case .recordWindow: await recordWindow()
        case .recordScreen: await recordScreen()
        case .stopRecording: await recording.stop()
        case .translateArea: await translateArea()
        case .showCaptureHistory: capture.showHistory()
        case .showTranslationHistory: translation.showHistory()
        case .openImage: openImage()
        case .showSettings, .showOnboarding, .quit: break
        }
    }

    /// Lightshot-style: select an area and annotate it where it is, without the Quick Access Overlay (PLAN §17).
    private var instantCaptureCommand: ToolCommand {
        ToolCommand(
            id: "captureInstant",
            title: "Instant Capture",
            symbol: "bolt.square",
            group: .capture,
            defaultShortcut: KeyCombo(keyCode: KeyCode.ansi2, modifiers: [.control, .shift]),
            route: "capture/instant"
        ) { [weak self] in
            Task { await self?.instantCapture() }
        }
    }

    private func instantCapture() async {
        guard let region = await capture.selectRegion(prompt: "Select the area to annotate") else { return }
        do {
            let shot = try await capture.captureRect(region.rect)
            editor.openInstant(shot, at: region.rect)
        } catch {
            Toast.show(error.localizedDescription, symbol: "exclamationmark.triangle")
        }
    }

    /// The record shortcut toggles: pressed during a recording, it stops it.
    private func recordArea() async {
        guard !recording.isActive else {
            await recording.stop()
            return
        }
        guard let region = await capture.selectRegion(prompt: "Select the area to record") else { return }
        await start(.region(region.rect, displayID: region.displayID))
    }

    /// Records the picked window's frame, so Oriel's click rings, keystrokes and camera bubble stay in the video.
    private func recordWindow() async {
        guard !recording.isActive else {
            await recording.stop()
            return
        }
        guard let window = await capture.selectWindow(prompt: "Click the window to record") else { return }
        await start(.window(window.windowID))
    }

    private func recordScreen() async {
        guard !recording.isActive else {
            await recording.stop()
            return
        }
        let display = ScreenLocator.screenUnderMouse.flatMap(ScreenLocator.displayID(of:)) ?? CGMainDisplayID()
        await start(.display(display))
    }

    private func start(_ target: RecordingTarget) async {
        do {
            try await recording.start(target)
        } catch {
            log.error("recording did not start: \(error.localizedDescription, privacy: .public)")
            Toast.show(error.localizedDescription, symbol: "exclamationmark.triangle")
        }
    }

    private func translateArea() async {
        guard let region = await capture.selectRegion(prompt: "Select the text to translate") else { return }
        do {
            try await translation.translate(capture.captureRect(region.rect))
        } catch {
            Toast.show(error.localizedDescription, symbol: "exclamationmark.triangle")
        }
    }

    private func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image, .package]
        panel.message = "Choose an image or an Oriel document to edit."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(fileAt: url)
    }

    /// Images and `.oriel` documents opened from Finder or with "Open With".
    func open(fileAt url: URL) {
        do {
            try editor.open(fileAt: url)
        } catch {
            LaunchChecks.alert("Oriel cannot open \(url.lastPathComponent)", error.localizedDescription)
        }
    }

    // MARK: CaptureActionHandling

    func annotate(_ capture: CaptureResult) {
        editor.open(capture)
    }

    func translate(_ capture: CaptureResult) {
        Task { await translation.translate(capture) }
    }

    func upload(_ capture: CaptureResult) {
        Task { await uploads.upload(capture.image, scale: capture.scale, name: capture.windowTitle ?? "Oriel") }
    }

    // MARK: Settings, bootstrap, shutdown

    /// A tab for each tool with a pane, named after its module ID, then the features' tabs.
    var settingsPanes: [SettingsPaneEntry] {
        let tools = modules.compactMap { module in
            module.settingsPane.map { view in
                SettingsPaneEntry(id: type(of: module).id.rawValue, title: module.displayName, symbol: module.settingsSymbol, view: view)
            }
        }
        return tools + [
            SettingsPaneEntry(id: "capture", title: "Capture", symbol: "camera.viewfinder", view: capture.settingsPane),
            SettingsPaneEntry(id: "recording", title: "Recording", symbol: "record.circle", view: recording.settingsPane),
            SettingsPaneEntry(id: "translation", title: "Translation", symbol: "character.bubble", view: translation.settingsPane),
            SettingsPaneEntry(
                id: "editor",
                title: "Editor",
                symbol: "pencil.and.outline",
                view: AnyView(EditorSettingsView(settings: settings))
            ),
            SettingsPaneEntry(
                id: "upload",
                title: "Upload",
                symbol: "icloud.and.arrow.up",
                view: AnyView(UploadSettingsView(settings: settings, keychain: keychain, coordinator: uploads))
            ),
        ]
    }

    var keychainServices: [String] {
        translation.keychainServices + [UploadSettings.keychainService, ClipboardHistoryModule.keychainService]
    }

    func applyBootstrap(providers: [BootstrapProvider], defaultProvider: String?) {
        translation.applyBootstrap(providers, defaultProvider: defaultProvider)
    }

    var translationPair: (source: String, target: String) {
        let target = translation.defaultTargetCode
        return (target.hasPrefix("en") ? "ja" : "en", target)
    }

    func shutdown() async {
        if recording.isActive {
            await recording.stop()
        }
    }

    // MARK: CLI

    #if !APP_STORE
        /// The command-line tool's verbs; the App Store edition has no CLI (PLAN §19).
        var ipcCommands: [IPCCommandHandler] {
            ["area", "window", "screen"].map(captureCommand) + capture.ipcCommands
                + [translateCommand, fixtureCommand, recordCommand, perfCaptureCommand]
        }

        private func captureCommand(_ kind: String) -> IPCCommandHandler {
            let usage = "capture \(kind) [--rect x,y,w,h] [--delay <seconds>] [--to clipboard|file|editor] [--path <file>]"
            return IPCCommandHandler(verb: "capture.\(kind)", usage: usage) { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                return await runCapture(kind, request)
            }
        }

        private func runCapture(_ kind: String, _ request: IPCRequest) async -> IPCResponse {
            do {
                let result: CaptureResult?
                var interactive = false
                // The countdown comes first, so whatever is opened meanwhile (a menu, say) is in the shot.
                let delay = request.options["delay"].flatMap(Int.init).map { Duration.seconds($0) } ?? .zero
                guard await capture.countDown(delay) else { return .failure(request, "Cancelled.") }
                if let rect = request.options["rect"].flatMap(CommandParser.parseRect) {
                    result = try await capture.captureRect(rect)
                } else if kind == "window", let id = request.arguments.first.flatMap(UInt32.init) {
                    result = try await capture.captureWindow(windowID: id)
                } else if kind == "screen" {
                    result = try await capture.captureScreen(displayID: nil)
                } else {
                    interactive = true
                    result = await capture.capture(kind == "window" ? .window : .area)
                }
                guard let result else { return .failure(request, "Cancelled.") }
                // Interactive captures already ran the after-capture action; only an explicit --to adds one.
                let destination = request.options["to"] ?? (interactive ? "none" : "file")
                switch destination {
                case "none":
                    return .ok(request, "Captured \(result.image.width)×\(result.image.height) px.")
                case "clipboard":
                    Pasteboard.copy(result.image)
                    return .ok(request, "Copied \(result.image.width)×\(result.image.height) px to the clipboard.")
                case "editor":
                    editor.open(result)
                    return .ok(request, "Opened in the editor.")
                case "file":
                    let path = request.options["path"].map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
                    return try .ok(request, capture.save(result, to: path).path)
                default:
                    return .failure(request, "--to must be clipboard, file or editor.", status: 64)
                }
            } catch {
                return .failure(request, error.localizedDescription)
            }
        }

        private var translateCommand: IPCCommandHandler {
            let usage = "translate area [--rect x,y,w,h] [--to <language>] [--provider <id>] [--json]"
            return IPCCommandHandler(verb: "translate.area", usage: usage) { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                return await runTranslate(request)
            }
        }

        private func runTranslate(_ request: IPCRequest) async -> IPCResponse {
            do {
                let rect: CGRect
                if let given = request.options["rect"].flatMap(CommandParser.parseRect) {
                    rect = given
                } else if let selection = await capture.selectRegion(prompt: "Select the text to translate") {
                    rect = selection.rect
                } else {
                    return .failure(request, "Cancelled.")
                }
                let shot = try await capture.captureRect(rect)
                let outcome = try await translation.translateHeadless(
                    image: shot.image,
                    target: request.options["to"],
                    providerID: request.options["provider"]
                )
                guard request.flag("json") else {
                    let text = outcome.blocks.map { "\($0.source)\n→ \($0.translation ?? "(not translated)")" }.joined(separator: "\n\n")
                    return .ok(request, text.isEmpty ? "No text found." : text)
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return try .ok(request, String(data: encoder.encode(outcome), encoding: .utf8) ?? "{}")
            } catch {
                return .failure(request, error.localizedDescription)
            }
        }

        /// `oriel debug capture --fixture <png>` shows the Quick Access Overlay for an image file (PLAN §14.3).
        private var fixtureCommand: IPCCommandHandler {
            IPCCommandHandler(verb: "debug.capture", usage: "debug capture --fixture <png>") { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                guard let path = request.options["fixture"] else { return .failure(request, "--fixture <png> is required.", status: 64) }
                guard let image = ImageFile.load(URL(fileURLWithPath: (path as NSString).expandingTildeInPath)) else {
                    return .failure(request, "Cannot read \(path).")
                }
                capture.present(CaptureResult(image: image, kind: .imported, rect: .zero, scale: 2))
                return .ok(request, "Presented \(image.width)×\(image.height) px.")
            }
        }

        /// `oriel debug record --seconds <n> [--pause-at <s> --resume-at <s>]` records the main display for
        /// scripts/verify-recording.sh (PLAN §13.6) and answers with the saved movie's path.
        private var recordCommand: IPCCommandHandler {
            let usage = "debug record --seconds <n> [--pause-at <s> --resume-at <s>]"
            return IPCCommandHandler(verb: "debug.record", usage: usage) { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                return await runRecord(request)
            }
        }

        private func runRecord(_ request: IPCRequest) async -> IPCResponse {
            guard let seconds = request.options["seconds"].flatMap(Double.init), seconds > 0 else {
                return .failure(request, "--seconds <n> is required.", status: 64)
            }
            let pause = request.options["pause-at"].flatMap(Double.init)
            let resume = request.options["resume-at"].flatMap(Double.init)
            if pause != nil || resume != nil {
                guard let pause, let resume, pause > 0, pause < resume, resume < seconds else {
                    return .failure(request, "--pause-at and --resume-at must satisfy 0 < pause < resume < seconds.", status: 64)
                }
            }
            do {
                try await recording.start(.display(CGMainDisplayID()))
            } catch {
                return .failure(request, error.localizedDescription)
            }
            let clock = ContinuousClock()
            let started = clock.now
            if let pause, let resume {
                try? await clock.sleep(until: started + .seconds(pause))
                await recording.togglePause()
                try? await clock.sleep(until: started + .seconds(resume))
                await recording.togglePause()
            }
            try? await clock.sleep(until: started + .seconds(seconds))
            let files = await recording.stop()
            guard files.count == 1, let movie = files.first else {
                let parts = files.map(\.path).joined(separator: ", ")
                return .failure(request, files.isEmpty ? "The recording was not saved." : "The parts were not joined: \(parts)")
            }
            return .ok(request, movie.path)
        }

        /// `oriel debug perf-capture [--runs <n>] [--json]`: the capture-to-overlay latency in milliseconds, for
        /// scripts/perf-capture.sh (PLAN §9, §13.3).
        private var perfCaptureCommand: IPCCommandHandler {
            IPCCommandHandler(verb: "debug.perf-capture", usage: "debug perf-capture [--runs <n>] [--json]") { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                let runs = request.options["runs"].flatMap(Int.init) ?? 20
                guard (1 ... 200).contains(runs) else { return .failure(request, "--runs must be between 1 and 200.", status: 64) }
                do {
                    let milliseconds = try await capture.measureOverlayLatency(runs: runs).map { $0 / .milliseconds(1) }
                    let sorted = milliseconds.sorted()
                    // Nearest rank.
                    let percentile = { (fraction: Double) in sorted[max(0, Int((fraction * Double(sorted.count)).rounded(.up)) - 1)] }
                    guard request.flag("json") else {
                        return .ok(request, String(
                            format: "p50 %.1f ms, p95 %.1f ms, max %.1f ms over %d runs",
                            percentile(0.5),
                            percentile(0.95),
                            sorted.last ?? 0,
                            sorted.count
                        ))
                    }
                    let report: [String: Any] = ["milliseconds": milliseconds, "p50": percentile(0.5), "p95": percentile(0.95)]
                    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                    return .ok(request, String(data: data, encoding: .utf8) ?? "{}")
                } catch {
                    return .failure(request, error.localizedDescription)
                }
            }
        }
    #endif
}
