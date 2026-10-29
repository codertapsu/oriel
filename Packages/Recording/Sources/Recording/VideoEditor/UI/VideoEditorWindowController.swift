import AppKit
import AVFoundation
import OrielCore
import SharedUI

/// One video editor window (PLAN §17): the preview, the transport bar and the timeline on the left, the inspector
/// on the right, and a toolbar with the main actions. The window controller connects them to the session and
/// to playback.
final class VideoEditorWindowController: NSWindowController, NSWindowDelegate {
    static let minimumContentSize = CGSize(width: 860, height: 560)

    let session: VideoEditorSession
    let playback: VideoEditorPlayback
    let thumbnails: ThumbnailCache
    let settings: SettingsStore
    let textRecognizer: (any TextRecognizing)?
    let log = Log.logger("video-editor")

    /// Called when the window has closed.
    var onClose: ((VideoEditorWindowController) -> Void)?
    /// ⌘O and the toolbar's Open: choose another movie.
    var onOpen: (() -> Void)?
    /// A movie was dropped on the window; `replacing` is this window when it has nothing to lose.
    var onOpenDropped: ((URL, VideoEditorWindowController?) -> Void)?

    let playerView: PlayerView
    let transport = TransportBar()
    let timeline: TimelineView
    let inspector: VideoEditorInspector
    let splitController = NSSplitViewController()
    var exportTask: Task<Void, Never>?
    var textTask: Task<Void, Never>?
    var focusFrameTask: Task<Void, Never>?
    var textPanel: FrameTextPanel?
    weak var exportAccessory: ExportAccessoryView?
    weak var exportPanel: NSSavePanel?
    private var shownPlan = ZoomPlan.none
    private var shownRange: ClosedRange<Double>?
    private var toolbarItems: [NSToolbarItem.Identifier: NSToolbarItem] = [:]

    init(session: VideoEditorSession, settings: SettingsStore, textRecognizer: (any TextRecognizing)?) {
        self.session = session
        self.settings = settings
        self.textRecognizer = textRecognizer
        playback = VideoEditorPlayback(info: session.info)
        thumbnails = ThumbnailCache(info: session.info, height: TimelineView.stripHeight * 2)
        playerView = PlayerView(player: playback.player)
        timeline = TimelineView(session: session, thumbnails: thumbnails)
        inspector = VideoEditorInspector(session: session)
        let window = VideoEditorWindow(
            contentRect: CGRect(origin: .zero, size: Self.initialContentSize(on: ScreenLocator.screenUnderMouse)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        super.init(window: window)
        window.delegate = self
        configure(window)
        connect()
        sessionDidChange()
        timeDidChange(0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The window's first size: large enough to work in, within 85 % of the screen.
    static func initialContentSize(on screen: NSScreen?) -> CGSize {
        let visible = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let width = min(max(visible.width * 0.85, minimumContentSize.width), 1280)
        let height = min(max(visible.height * 0.85, minimumContentSize.height), 860)
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    /// Shows the window in front, centred on the screen under the pointer the first time.
    func present(at frame: CGRect? = nil) {
        guard let window else { return }
        if let frame {
            window.setFrame(frame, display: false)
        } else if !window.isVisible, let screen = ScreenLocator.screenUnderMouse {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        // Oriel is a menu-bar app: activate it, or the window opens behind the app the user is in.
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(timeline)
    }

    // MARK: Layout

    private func configure(_ window: VideoEditorWindow) {
        window.title = session.title
        window.representedURL = session.url
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentMinSize = Self.minimumContentSize
        window.animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .documentWindow
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.toolbarStyle = .unified
        window.commandHandler = { [weak self] command in
            self?.perform(command) ?? false
        }

        let main = NSViewController()
        main.view = mainView()
        let inspectorController = NSViewController()
        inspectorController.view = inspector
        let mainItem = NSSplitViewItem(viewController: main)
        mainItem.minimumThickness = 520
        let inspectorItem = NSSplitViewItem(inspectorWithViewController: inspectorController)
        inspectorItem.minimumThickness = VideoEditorInspector.width
        inspectorItem.maximumThickness = VideoEditorInspector.width + 80
        inspectorItem.canCollapse = true
        splitController.addSplitViewItem(mainItem)
        splitController.addSplitViewItem(inspectorItem)
        window.contentViewController = splitController
        window.setContentSize(Self.initialContentSize(on: ScreenLocator.screenUnderMouse))

        let toolbar = NSToolbar(identifier: "com.codertapsu.oriel.video-editor")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
    }

    /// The preview over the transport bar and the timeline, which accepts dropped movies.
    private func mainView() -> NSView {
        let content = MovieDropView()
        content.onDrop = { [weak self] url in
            self?.openDropped(url)
        }
        let top = Self.separator()
        let middle = Self.separator()
        for view in [playerView, top, transport, middle, timeline] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor),
            playerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            top.topAnchor.constraint(equalTo: playerView.bottomAnchor),
            transport.topAnchor.constraint(equalTo: top.bottomAnchor),
            middle.topAnchor.constraint(equalTo: transport.bottomAnchor),
            timeline.topAnchor.constraint(equalTo: middle.bottomAnchor),
            timeline.heightAnchor.constraint(equalToConstant: TimelineView.preferredHeight),
            timeline.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        return content
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: Connections

    private func connect() {
        session.onChange = { [weak self] in
            self?.sessionDidChange()
        }
        playback.onTime = { [weak self] time in
            self?.timeDidChange(time)
        }
        playback.onRateChange = { [weak self] _ in
            self?.updateTransport()
        }
        timeline.onSeek = { [weak self] time, scrubbing in
            guard let self else { return }
            if scrubbing, playback.isPlaying {
                playback.stop()
            }
            playback.seek(to: time, exact: !scrubbing)
        }
        timeline.onStep = { [weak self] seconds in
            self?.playback.step(seconds: seconds)
        }
        timeline.onRenameChapter = { [weak self] id in
            self?.renameChapter(id)
        }
        timeline.onMappingChange = { [weak self] in
            guard let self else { return }
            transport.setZoomFraction(timeline.zoomFraction)
        }
        transport.onCommand = { [weak self] command in
            _ = self?.perform(command)
        }
        transport.onZoom = { [weak self] fraction in
            self?.timeline.zoomFraction = fraction
        }
        inspector.onSeek = { [weak self] time in
            self?.playback.seek(to: time)
        }
        inspector.currentTime = { [weak self] in
            self?.playback.currentTime ?? 0
        }
        inspector.onAutoZoomSettings = { [weak self] autoZoom in
            self?.settings[RecordingSettingKeys.autoZoomLevel] = autoZoom.level
            self?.settings[RecordingSettingKeys.autoZoomHold] = autoZoom.hold
        }
        inspector.onCopyTimestamps = { [weak self] in
            self?.copyTimestamps()
        }
        inspector.onSaveTimestamps = { [weak self] in
            self?.saveTimestamps()
        }
        inspector.onNeedsFocusFrame = { [weak self] time in
            self?.loadFocusFrame(at: time)
        }
    }

    /// Shows the session's state everywhere: the timeline, the inspector, the preview's zoom and the trim.
    func sessionDidChange() {
        timeline.sessionDidChange()
        inspector.update()
        let plan = session.edit.zoomPlan
        if plan != shownPlan {
            shownPlan = plan
            playback.setComposition(plan.isEmpty ? nil : previewComposition(plan))
        }
        let range = session.range
        if range != shownRange {
            shownRange = range
            playback.setRange(range)
        }
        window?.isDocumentEdited = session.hasUnexportedChanges
        updateTransport()
        updateToolbar()
    }

    private func timeDidChange(_ time: Double) {
        timeline.playhead = time
        if playback.isPlaying {
            timeline.reveal(time)
        }
        updateTransport(time: time)
        inspector.playheadDidMove()
    }

    private func updateTransport(time: Double? = nil) {
        let edit = session.edit
        transport.update(
            time: time ?? playback.currentTime,
            duration: session.duration,
            isPlaying: playback.isPlaying,
            range: session.range,
            isTrimmed: edit.trimStart != nil || edit.trimEnd != nil
        )
        transport.setZoomFraction(timeline.zoomFraction)
    }

    /// The zoom as the preview shows it: at most 1920 pixels across, at the movie's frame rate.
    private func previewComposition(_ plan: ZoomPlan) -> AVVideoComposition {
        let info = session.info
        return ZoomComposition.make(
            ZoomComposition.Source(trackID: info.videoTrackID, size: info.size, orientation: info.orientation),
            duration: info.duration,
            plan: plan,
            renderSize: ZoomComposition.previewSize(for: info.size),
            frameRate: EditedMovieExporter.zoomFrameRate(for: info)
        )
    }

    /// Reads the focus picker's frame, a moment after the last request, so dragging a zoom decodes one frame
    /// rather than one per mouse move.
    private func loadFocusFrame(at time: Double) {
        focusFrameTask?.cancel()
        let url = session.url
        focusFrameTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let image = try? await FrameReader.image(of: url, at: time, maximumSize: CGSize(width: 640, height: 640))
            guard !Task.isCancelled, let self, inspector.focusFrameTime == time else { return }
            inspector.focusPicker.image = image
        }
    }

    // MARK: Closing

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard session.hasUnexportedChanges, exportTask == nil else { return exportTask == nil }
        let alert = NSAlert()
        alert.messageText = "Close without exporting?"
        alert.informativeText = "The trim, zooms and chapters of “\(session.title)” are kept only until the window closes."
        alert.addButton(withTitle: "Export…")
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        Task { @MainActor [weak self] in
            let response = await alert.beginSheetModal(for: sender)
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn:
                export()
            case .alertSecondButtonReturn:
                session.markExported()
                sender.close()
            default:
                break
            }
        }
        return false
    }

    func windowWillClose(_: Notification) {
        exportTask?.cancel()
        textTask?.cancel()
        focusFrameTask?.cancel()
        textPanel?.close()
        thumbnails.cancel()
        playback.close()
        session.onChange = nil
        let onClose = onClose
        Task { onClose?(self) }
    }

    func windowWillReturnUndoManager(_: NSWindow) -> UndoManager? {
        session.undoManager
    }

    // MARK: Toolbar state

    func updateToolbar() {
        toolbarItems[.autoZoom]?.isEnabled = session.clicks != nil
        toolbarItems[.copyText]?.isEnabled = textRecognizer != nil
        toolbarItems[.export]?.isEnabled = exportTask == nil
    }

    func register(_ item: NSToolbarItem) {
        toolbarItems[item.itemIdentifier] = item
    }
}
