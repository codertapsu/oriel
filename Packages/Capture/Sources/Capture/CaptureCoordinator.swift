import AppKit
import OrielCore
import os
import Permissions
import SharedUI
import SwiftUI

/// The snipping tool (PLAN §1.3, §7.2, §7.3): interactive captures on a freeze-frame overlay, headless captures for
/// the CLI, the Quick Access Overlay, pins and capture history. The app creates one at launch and keeps it; it uses
/// no CPU while idle (no timers, only notification observers).
public final class CaptureCoordinator {
    /// Annotate, translate and upload, implemented by the app, so Capture never links the editor, translation or
    /// upload. Quick Access and history hide those actions while this is nil.
    public weak var actions: (any CaptureActionHandling)?

    /// The save folder resolved from its bookmark, in the App Store edition.
    private var resolvedSaveFolder: (bookmark: Data, url: URL)?
    let settings: SettingsStore
    let permissions: PermissionCenter
    let textRecognizer: (any TextRecognizing)?
    let cache = ShareableContentCache()
    let engine = ScreenshotEngine()
    let history: HistoryStore
    let historyWindow = HistoryWindowController()
    let log = Log.logger("capture")
    let signposter = OSSignposter(subsystem: Log.subsystem, category: "capture")
    lazy var quickAccess = makeQuickAccess()
    lazy var pins = makePins()
    lazy var textPanel = CapturedTextPanel()
    lazy var textHUD = TextRecognitionHUD()
    var historyModel: HistoryModel?
    var indexing: Task<Void, Never>?
    var isBusy = false
    /// The running Step Capture, which every capture joins as its next step.
    var stepCapture: StepCaptureController?
    /// Finished step sequences, one window each, until closed.
    var stepWindows: [StepSequenceWindowController] = []
    /// HDR versions of the latest captures, kept only when HEIC with HDR is on; everything else uses SDR.
    var hdrImages: [UUID: CGImage] = [:]
    var hdrOrder: [UUID] = []

    /// - Parameters:
    ///   - settings: Capture reads and writes its `capture.*` settings here.
    ///   - permissions: Screen Recording is requested before every interactive capture, Accessibility before
    ///     automatic scrolling.
    ///   - textRecognizer: OCR for "Copy Text" and history search; nil hides both.
    public convenience init(settings: SettingsStore, permissions: PermissionCenter, textRecognizer: (any TextRecognizing)?) {
        self.init(settings: settings, permissions: permissions, textRecognizer: textRecognizer, historyDirectory: AppPaths.captureHistory)
    }

    init(settings: SettingsStore, permissions: PermissionCenter, textRecognizer: (any TextRecognizing)?, historyDirectory: URL) {
        self.settings = settings
        self.permissions = permissions
        self.textRecognizer = textRecognizer
        history = HistoryStore(directory: historyDirectory)
    }

    /// The delay "Capture with Timer" should pass to `capture(_:delay:)` (Settings → Capture → Timer).
    public var timerDelay: Duration {
        .seconds(settings[CaptureSettings.timerSeconds])
    }

    /// Interactive capture. Requests Screen Recording first and explains when it is denied. After capturing it runs the
    /// configured after-capture action (the Quick Access Overlay by default; or copy, save, or open the editor) and
    /// adds the result to history when that is on. Returns nil when cancelled, or while another capture is running.
    @discardableResult
    public func capture(_ mode: CaptureMode, delay: Duration = .zero) async -> CaptureResult? {
        guard !isBusy else {
            log.info("A capture was asked for while another one was running")
            return nil
        }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording(), await countDown(delay) else { return nil }
        do {
            guard let captured = try await interactiveCapture(mode) else { return nil }
            deliver(captured)
            return captured.result
        } catch {
            log.error("Capture failed: \(error.localizedDescription, privacy: .private)")
            PermissionPrompt.show(error)
            return nil
        }
    }

    /// Shows the countdown for `delay` (whole seconds, at least one) on the screen under the pointer, and returns
    /// false when the user cancels it with its Cancel button. A zero delay returns at once. For the CLI's `--delay`;
    /// interactive captures pass their delay to `capture(_:delay:)`.
    public func countDown(_ delay: Duration) async -> Bool {
        guard delay > .zero else { return true }
        let seconds = max(1, Int((delay / .seconds(1)).rounded(.up)))
        return await CountdownPanel.run(seconds: seconds)
    }

    /// Area selection that returns the region instead of capturing it, for recording and translation. `prompt` is
    /// shown at the top of the screen. Returns nil when cancelled.
    public func selectRegion(prompt: String) async -> RegionSelection? {
        guard case let .area(rect, displayID, _) = await select(.area, prompt: prompt) else { return nil }
        return RegionSelection(rect: rect, displayID: displayID)
    }

    /// Window selection that returns the window instead of capturing it, for Record Window. `prompt` is shown at the
    /// top of the screen. Returns nil when cancelled.
    public func selectWindow(prompt: String) async -> WindowSelection? {
        guard case let .window(target, _) = await select(.window, prompt: prompt) else { return nil }
        return WindowSelection(windowID: target.id, frame: target.frame, title: target.title, appName: target.appName)
    }

    /// The overlay in one mode, without switching or capturing; nil after an error, which is explained to the user.
    private func select(_ mode: OverlayMode, prompt: String) async -> OverlayOutcome? {
        guard !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording() else { return nil }
        do {
            let screens = try await prepareSelection(keepsHDR: false)
            var configuration = OverlayConfiguration(mode: mode)
            configuration.allowsModeSwitch = false
            configuration.prompt = prompt
            configuration.tools = OverlayTool.confirmTools
            configuration.showsMagnifier = settings[CaptureSettings.showsMagnifier]
            let overlay = FreezeFrameOverlay(backdrops: screens.backdrops, windows: screens.windows, configuration: configuration)
            return await overlay.run()
        } catch {
            log.error("Selection failed: \(error.localizedDescription, privacy: .private)")
            PermissionPrompt.show(error)
            return nil
        }
    }

    /// Shows the Quick Access Overlay for any result (also used for `oriel debug capture --fixture`).
    public func present(_ result: CaptureResult) {
        quickAccess.present(result, actions: quickAccessActions)
    }

    /// Writes `result` as PNG, JPEG or HEIC with its scale as DPI, and returns the file written. With `url` nil it
    /// goes to the default folder (Settings → Capture, else the Desktop) named by the filename template; a directory
    /// `url` gets a template name too; a file `url` picks the format from its extension.
    @discardableResult
    public func save(_ result: CaptureResult, to url: URL?) throws -> URL {
        let (destination, format) = try destination(for: result, url: url)
        if let data = hdrHEICData(for: result, format: format) {
            try data.write(to: destination, options: .atomic)
        } else {
            try ImageFile.write(result.image, to: destination, format: format.imageFileFormat, scale: result.scale)
        }
        log.info("Saved a capture to \(destination.path, privacy: .private)")
        return destination
    }

    /// Pins `result` to the screen: a floating panel with opacity, zoom, click-through, a lock and a border.
    public func pin(_ result: CaptureResult) {
        pins.pin(result)
    }

    /// The status menu's Pinned submenu: each pinned capture with its commands (Bring to Front, opacity,
    /// click-through and the rest), Stop Click-Through on All Pins while one is, and Close All Pins. Nil while nothing
    /// is pinned.
    public func makePinnedMenu() -> NSMenu? {
        PinsMenu.make(
            for: pins.entries,
            perform: { [weak self] id, command in self?.pins.perform(command, on: id) },
            stopClickThrough: { [weak self] in self?.pins.stopClickThroughOnAllPins() },
            closeAll: { [weak self] in self?.pins.closeAll() }
        )
    }

    /// Opens the capture history window, applies the retention setting and indexes new captures for search.
    public func showHistory() {
        let model = historyModel ?? makeHistoryModel()
        historyModel = model
        historyWindow.show(model)
        let store = history
        let days = settings[CaptureSettings.historyRetentionDays]
        Task {
            _ = try? await store.prune(keepingDays: days)
            await model.reload()
            indexPendingHistory()
        }
    }

    /// Settings → Capture.
    public var settingsPane: AnyView {
        AnyView(CaptureSettingsView(
            settings: settings,
            showsTextCapture: textRecognizer != nil,
            onShowHistory: { [weak self] in self?.showHistory() },
            onClearHistory: { [weak self] in self?.clearHistory() }
        ))
    }

    // MARK: - Shared steps

    func ensureScreenRecording() async -> Bool {
        if permissions.status(of: .screenRecording) == .granted {
            return true
        }
        if await permissions.request(.screenRecording) == .granted {
            return true
        }
        PermissionPrompt.explainScreenRecording(permissions)
        return false
    }

    var keepsHDR: Bool {
        settings[CaptureSettings.format] == .heic && settings[CaptureSettings.keepsHDR]
    }

    var quickAccessActions: [QuickAccessAction] {
        QuickAccessAction.allCases.filter { action in
            switch action {
            case .annotate, .translate, .upload: actions != nil
            case .copyText: textRecognizer != nil
            case .copy, .save, .pin, .close: true
            }
        }
    }

    private func destination(for result: CaptureResult, url: URL?) throws -> (URL, CaptureImageFormat) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if let url, !url.hasDirectoryPath, !(fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
            let format = settings[CaptureSettings.format]
            guard !url.pathExtension.isEmpty else { return (url.appendingPathExtension(format.fileExtension), format) }
            guard let named = CaptureImageFormat(fileExtension: url.pathExtension) else {
                throw OrielError.invalidArgument("Oriel saves PNG, JPEG or HEIC files, not .\(url.pathExtension).")
            }
            return (url, named)
        }
        let format = settings[CaptureSettings.format]
        let folder = try AppPaths.ensureDirectory(url ?? defaultFolder)
        let name = FilenameTemplate.render(settings[CaptureSettings.filenameTemplate], context: FilenameTemplate.Context(result: result))
        let file = FilenameTemplate.uniqueURL(in: folder, baseName: name, fileExtension: format.fileExtension) {
            fileManager.fileExists(atPath: $0.path)
        }
        return (file, format)
    }

    /// HEIC that keeps HDR, when the format is HEIC, HDR is on and the capture has an HDR version.
    private func hdrHEICData(for result: CaptureResult, format: CaptureImageFormat) -> Data? {
        guard format == .heic, settings[CaptureSettings.keepsHDR], let hdr = hdrImages[result.id] else { return nil }
        return ImageEncoding.hdrHEICData(for: hdr, scale: result.scale)
    }

    /// The folder captures are saved to: the one chosen in Settings, else the Desktop. The App Store edition's sandbox
    /// reaches a chosen folder only through its bookmark and the Desktop not at all, so it falls back to Pictures/Oriel.
    var defaultFolder: URL {
        if Sandbox.isActive {
            return grantedSaveFolder ?? picturesFolder
        }
        if let path = settings[CaptureSettings.saveFolder] {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// The chosen folder through its bookmark, resolved once per bookmark.
    private var grantedSaveFolder: URL? {
        guard let bookmark = settings[CaptureSettings.saveFolderBookmark] else { return nil }
        if let granted = resolvedSaveFolder, granted.bookmark == bookmark {
            return granted.url
        }
        let url = FolderBookmark.resolve(bookmark)
        resolvedSaveFolder = url.map { (bookmark, $0) }
        return url
    }

    /// Pictures/Oriel at its real path: in the sandbox the Pictures folder FileManager names is a link inside the
    /// container, which the toasts and Finder would show.
    private var picturesFolder: URL {
        let pictures = (FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser).resolvingSymlinksInPath()
        return (try? AppPaths.ensureDirectory(pictures.appending(path: "Oriel", directoryHint: .isDirectory))) ?? pictures
    }
}
