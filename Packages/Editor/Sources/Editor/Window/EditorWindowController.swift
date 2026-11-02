import AppKit
import OrielCore
import SharedUI
import SwiftUI

/// One editor window: the tool strip, the zoomable canvas and the action bar around an `EditorSession`.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    /// Wide enough for the whole tool strip, with the step options and the smart tools.
    static let minimumContentSize = CGSize(width: 780, height: 420)
    static let toolbarHeight: CGFloat = 44
    static let actionBarHeight: CGFloat = 40
    static let zoomSteps: [CGFloat] = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6, 8]
    static let zoomRange: ClosedRange<CGFloat> = 0.05 ... 8

    let session: EditorSession
    /// The capture this window shows, so opening it again brings this window forward.
    let captureID: UUID?
    var onUpload: ((CGImage) -> Void)? {
        didSet { session.uploadAvailable = onUpload != nil }
    }

    var onClose: ((EditorWindowController) -> Void)?

    let canvas: EditorCanvasView
    /// The background panel's model: pictures and saved presets.
    let backgroundTool: BackgroundTool
    /// Smart Redact, Simplify and Smart Move; nil without an analyzer (tests).
    let smartTools: SmartTools?
    let log = Log.logger("editor")
    /// The format picked in this window's last export panel.
    var exportFormat: EditorExportFormat
    /// The export panel while it is open.
    var exportPanel: ExportPanel?
    /// Set when "Save…" was chosen while closing: the window closes once the save succeeds.
    var closesAfterSaving = false
    /// The PNG Quick Look is showing, while it is.
    var quickLookURL: URL?

    private let container: CanvasContainerView
    private let scrollView = NSScrollView()
    private var displayedCanvasSize: CGSize = .zero

    /// - Parameters:
    ///   - library: the saved backgrounds; nil hides them.
    ///   - analyzer: the smart tools' OCR and detection; nil hides the smart tools.
    init(session: EditorSession, captureID: UUID? = nil, library: BackgroundLibrary? = nil, analyzer: SmartAnalyzer? = nil) {
        self.session = session
        self.captureID = captureID
        exportFormat = session.defaults.exportFormat
        canvas = EditorCanvasView(session: session)
        backgroundTool = BackgroundTool(session: session, library: library)
        smartTools = analyzer.map { SmartTools(session: session, analyzer: $0) }
        container = CanvasContainerView(canvas: canvas)
        let size = Self.initialContentSize(for: session.layout.canvasSize, on: ScreenLocator.screenUnderMouse)
        let window = EditorWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init(window: window)
        window.delegate = self
        backgroundTool.window = window
        configure(window)
        let handler: (EditorCommand) -> Bool = { [weak self] command in self?.perform(command) ?? false }
        canvas.commandHandler = handler
        window.commandHandler = handler
        container.onMagnify = { [weak self] zoom, anchor in self?.setZoom(zoom, anchor: anchor) }
        session.onChange = { [weak self] in self?.sessionDidChange() }
        displayedCanvasSize = session.layout.canvasSize
        container.layoutCanvas(size: displayedCanvasSize, zoom: session.zoom)
        // Size the scroll view now, so the first fit sees the real visible area.
        window.layoutIfNeeded()
        zoomToFit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the window in front, centred on the screen under the pointer the first time, zoomed to fit.
    func present() {
        guard let window else { return }
        if !window.isVisible, let screen = ScreenLocator.screenUnderMouse {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        // Oriel is a menu-bar app: activate it, or the window opens behind the app the user is in.
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
        if session.zoomsToFit {
            zoomToFit()
        }
    }

    /// The window's content size for a canvas: the canvas at 100 % plus chrome, within 85 % of the screen.
    static func initialContentSize(for canvasSize: CGSize, on screen: NSScreen?) -> CGSize {
        let visible = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let margin = CanvasContainerView.margin * 2
        let chrome = toolbarHeight + actionBarHeight + 2
        let width = min(max(canvasSize.width + margin, minimumContentSize.width), max(visible.width * 0.85, minimumContentSize.width))
        let height = min(
            max(canvasSize.height + margin + chrome, minimumContentSize.height),
            max(visible.height * 0.85, minimumContentSize.height)
        )
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    // MARK: - Commands

    /// Every key press and button ends up here.
    @discardableResult
    func perform(_ command: EditorCommand) -> Bool {
        switch command {
        case let .tool(tool):
            guard tool.proFeature.map(ProAccess.shared.check) ?? true else { return false }
            session.selectTool(tool)
        case .delete: session.deleteSelection()
        case let .nudge(dx, dy): session.nudgeSelection(dx: dx, dy: dy)
        case .cancel: session.cancel()
        case .confirm: session.confirm()
        case .undo: session.undo()
        case .redo: session.redo()
        case .selectAll: session.selectAll()
        case .copy: copyImage()
        case .save:
            guard ProAccess.shared.check(.editorDocuments) else { return false }
            save()
        case .export: export()
        case .quickLook: toggleQuickLook()
        case .zoomIn: zoomIn()
        case .zoomOut: zoomOut()
        case .zoomToFit: zoomToFit()
        case .actualSize: setZoom(1, anchor: nil)
        case .close: window?.performClose(nil)
        case .smartRedact:
            guard let smartTools, smartTools.canReadText, ProAccess.shared.check(.smartRedact) else { return false }
            session.commitPendingEdits()
            smartTools.isRedactPresented = true
        }
        return true
    }

    // MARK: - Zoom

    func zoomIn() {
        setZoom(Self.zoomSteps.first { $0 > session.zoom * 1.001 } ?? Self.zoomRange.upperBound, anchor: nil)
    }

    func zoomOut() {
        setZoom(Self.zoomSteps.last { $0 < session.zoom * 0.999 } ?? Self.zoomRange.lowerBound, anchor: nil)
    }

    /// Fits the canvas in the window (never above 100 %) and keeps fitting as the window resizes.
    func zoomToFit() {
        session.zoomsToFit = true
        let size = session.layout.canvasSize
        let available = scrollView.contentSize
        let margin = CanvasContainerView.margin * 2
        guard size.width > 0, size.height > 0, available.width > margin, available.height > margin else {
            applyZoom(session.zoom, anchor: nil)
            return
        }
        applyZoom(min((available.width - margin) / size.width, (available.height - margin) / size.height, 1), anchor: nil)
    }

    /// Sets a fixed zoom, keeping the canvas point under `anchor` (canvas-view coordinates; default: the
    /// middle of the visible area) where it is.
    func setZoom(_ zoom: CGFloat, anchor: CGPoint?) {
        session.zoomsToFit = false
        applyZoom(zoom, anchor: anchor)
    }

    private func applyZoom(_ zoom: CGFloat, anchor: CGPoint?) {
        let clamped = min(max(zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        let clip = scrollView.contentView
        let oldZoom = max(session.zoom, 0.0001)
        let anchorInCanvas = anchor ?? canvas.convert(CGPoint(x: clip.bounds.midX, y: clip.bounds.midY), from: clip)
        let anchorInClip = clip.convert(anchorInCanvas, from: canvas)
        let offset = CGPoint(x: anchorInClip.x - clip.bounds.minX, y: anchorInClip.y - clip.bounds.minY)
        let canvasPoint = CGPoint(x: anchorInCanvas.x / oldZoom, y: anchorInCanvas.y / oldZoom)
        session.zoom = clamped
        displayedCanvasSize = session.layout.canvasSize
        container.layoutCanvas(size: displayedCanvasSize, zoom: clamped)
        let moved = clip.convert(CGPoint(x: canvasPoint.x * clamped, y: canvasPoint.y * clamped), from: canvas)
        let target = CGRect(origin: CGPoint(x: moved.x - offset.x, y: moved.y - offset.y), size: clip.bounds.size)
        clip.setBoundsOrigin(clip.constrainBoundsRect(target).origin)
        scrollView.reflectScrolledClipView(clip)
        canvas.sessionDidChange()
    }

    // MARK: - Session

    private func sessionDidChange() {
        if session.layout.canvasSize != displayedCanvasSize {
            if session.zoomsToFit {
                zoomToFit()
            } else {
                applyZoom(session.zoom, anchor: nil)
            }
        }
        canvas.sessionDidChange()
        window?.isDocumentEdited = session.hasUnsavedChanges
    }

    // MARK: - NSWindowDelegate

    func windowWillReturnUndoManager(_: NSWindow) -> UndoManager? {
        session.undoManager
    }

    func windowDidResize(_: Notification) {
        if session.zoomsToFit {
            zoomToFit()
        }
    }

    func windowWillClose(_: Notification) {
        smartTools?.endReview()
        removeQuickLookFile()
        session.onChange = nil
        session.effects.removeAll()
        onClose?(self)
    }

    // MARK: - Layout

    private func configure(_ window: EditorWindow) {
        window.title = session.title
        window.representedURL = session.fileURL
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentMinSize = Self.minimumContentSize
        window.animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .documentWindow
        window.collectionBehavior.insert(.fullScreenPrimary)

        scrollView.contentView = CenteringClipView()
        scrollView.documentView = container
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .underPageBackgroundColor

        let toolbar = NSHostingView(rootView: EditorToolbar(session: session, background: backgroundTool, smart: smartTools))
        let actionBar = NSHostingView(rootView: EditorActionBar(session: session, actions: makeActions()))
        toolbar.sizingOptions = []
        actionBar.sizingOptions = []
        let topSeparator = Self.separator()
        let bottomSeparator = Self.separator()
        let content = NSView()
        for view in [toolbar, topSeparator, scrollView, bottomSeparator, actionBar] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: Self.toolbarHeight),
            topSeparator.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            bottomSeparator.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            actionBar.topAnchor.constraint(equalTo: bottomSeparator.bottomAnchor),
            actionBar.heightAnchor.constraint(equalToConstant: Self.actionBarHeight),
            actionBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.initialFirstResponder = canvas
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func makeActions() -> EditorActions {
        EditorActions(
            copy: { [weak self] in self?.copyImage() },
            save: { [weak self] in self?.save() },
            export: { [weak self] in self?.export() },
            quickLook: { [weak self] in self?.toggleQuickLook() },
            upload: { [weak self] in self?.upload() },
            zoomIn: { [weak self] in self?.zoomIn() },
            zoomOut: { [weak self] in self?.zoomOut() },
            zoomToFit: { [weak self] in self?.zoomToFit() },
            actualSize: { [weak self] in self?.setZoom(1, anchor: nil) },
            dragPayload: { [weak self] in self?.makeDragPayload() },
            dragDelivered: { [weak self] in self?.delivered() }
        )
    }

    /// The user has the image now: nothing is lost by closing.
    func delivered() {
        session.markDelivered()
        window?.isDocumentEdited = false
    }
}
