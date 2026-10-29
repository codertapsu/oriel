import AppKit
import OrielCore
import SharedUI

/// Instant Capture (PLAN §17, Lightshot-style): the capture shown at 1:1 exactly where it was taken, annotated in
/// place with the editor's own session, canvas and renderer, and a compact toolbar beside it. Copy (⌘C or Return)
/// copies the result and closes, Save (⌘S) exports it, Upload sends it, Open in Editor (⌘E) moves it to a full editor
/// window with the annotations and their undo history, and Esc closes.
final class InstantCaptureController: NSObject, NSPopoverDelegate {
    let session: EditorSession
    /// The capture shown: the editor window Open in Editor makes belongs to it, so opening the capture again
    /// brings that window forward.
    let captureID: UUID
    let placement: InstantPlacement
    /// Uploads the result; the toolbar shows Upload when it was set at creation.
    var onUpload: ((CGImage) -> Void)?

    /// Hands the session over to a full editor window.
    var onOpenInEditor: ((EditorSession) -> Void)?
    var onClose: ((InstantCaptureController) -> Void)?

    let panel: InstantPanel
    let canvas: EditorCanvasView
    private(set) var toolbar: InstantToolbar
    let toolbarPanel = FloatingPanel(level: .statusBar, joinsAllSpaces: false)
    private let content: InstantContentView
    private var stylePopover: NSPopover?
    private var exportPanel: ExportPanel?
    private var colorPanelLevel: NSWindow.Level?
    private(set) var isClosed = false
    private let log = Log.logger("editor")

    /// What Copy labels its copy for Clipboard History.
    static let clipboardLabel = EditorLauncher.clipboardLabel

    /// - Parameters:
    ///   - selection: the selection in global CoreGraphics points, as `CaptureCoordinator.selectRegion` returns it.
    ///   - screens: the displays, primary first, in Cocoa coordinates.
    ///   - showsUpload: whether the toolbar offers Upload.
    /// - Returns: nil when no screen shows the selection.
    init?(
        session: EditorSession,
        captureID: UUID,
        selection: CGRect,
        screens: [InstantPlacement.Screen],
        primaryHeight: CGFloat,
        showsUpload: Bool
    ) {
        self.session = session
        self.captureID = captureID
        // A toolbar like the real one, to measure; the real one needs `self` for its actions.
        let toolbar = InstantToolbar(showsUpload: showsUpload, selectTool: { _ in }, showStyle: { _ in }, perform: { _ in })
        guard let placement = InstantPlacement.place(
            selection: selection, screens: screens, primaryHeight: primaryHeight, toolbarSize: toolbar.fittingSize
        ) else { return nil }
        self.placement = placement
        self.toolbar = toolbar
        canvas = EditorCanvasView(session: session)
        content = InstantContentView(canvas: canvas, canvasSize: placement.canvasFrame.size, margin: InstantPlacement.outlineMargin)
        panel = InstantPanel(contentRect: placement.panelFrame)
        super.init()
        // The image fills the selection at 1:1; if its point size differs from the selection's (a scale mismatch),
        // the zoom makes it fit exactly.
        let canvasSize = session.layout.canvasSize
        session.zoomsToFit = false
        session.zoom = canvasSize.width > 0 ? placement.canvasFrame.width / canvasSize.width : 1
        panel.contentView = content
        panel.initialFirstResponder = canvas
        let handler: (EditorCommand) -> Bool = { [weak self] command in self?.perform(command) ?? false }
        panel.commandHandler = handler
        canvas.commandHandler = handler
        session.onChange = { [weak self] in self?.sessionDidChange() }
        toolbarPanel.contentView = makeToolbar(showsUpload: showsUpload)
        toolbarPanel.setAccessibilityLabel("Instant Capture tools")
    }

    /// Shows the capture over the selection and the toolbar beside it, and takes the keyboard without activating
    /// Oriel. Nothing heavy happens here, so the panel appears right after the selection.
    func present() {
        panel.setFrame(placement.panelFrame, display: false)
        toolbarPanel.setFrame(placement.toolbarFrame, display: false)
        panel.orderFrontRegardless()
        panel.addChildWindow(toolbarPanel, ordered: .above)
        panel.makeKey()
        panel.makeFirstResponder(canvas)
        sessionDidChange()
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [
            .announcement: "Instant Capture. Draw on the capture; press Return to copy it, or Escape to close.",
        ])
    }

    // MARK: - Commands

    /// Key presses: the editor's keys for the tools Instant Capture has, plus Return and ⌘C to copy, ⌘S to save, ⌘E to
    /// open the editor and Esc or ⌘W to close.
    @discardableResult
    func perform(_ command: EditorCommand) -> Bool {
        switch command {
        case let .tool(tool):
            guard InstantToolbar.tools.contains(tool) else { return false }
            session.selectTool(tool)
        case .delete: session.deleteSelection()
        case let .nudge(dx, dy): session.nudgeSelection(dx: dx, dy: dy)
        case .selectAll: session.selectAll()
        case .undo: run(.undo)
        case .redo: run(.redo)
        case .copy, .confirm: run(.copy)
        case .save: run(.save)
        case .export: run(.openInEditor)
        case .close: run(.close)
        case .cancel:
            if session.gesture != nil || session.editingTextID != nil {
                session.cancel()
            } else {
                run(.close)
            }
        case .quickLook, .zoomIn, .zoomOut, .zoomToFit, .actualSize, .smartRedact:
            return false
        }
        return true
    }

    func run(_ action: InstantAction) {
        guard !isClosed else { return }
        switch action {
        case .undo: session.undo()
        case .redo: session.redo()
        case .copy: copyResult()
        case .save: save()
        case .upload: upload()
        case .openInEditor: openInEditor()
        case .close: close()
        }
    }

    // MARK: - Output

    /// Copies the result (labelled for Clipboard History) and closes.
    func copyResult() {
        guard let image = session.flattenedImage(), Pasteboard.copy(image, label: Self.clipboardLabel) else {
            NSSound.beep()
            return
        }
        Toast.show("Copied", symbol: "doc.on.doc", on: panel.screen)
        close()
    }

    /// The editor's export: a save panel in the editor's default format (Settings → Editor), with the format
    /// pop-up. The panel floats above the capture; Oriel comes to the front while it is open.
    func save() {
        session.commitPendingEdits()
        let export = ExportPanel(title: session.title, format: session.defaults.exportFormat, directory: nil)
        exportPanel = export
        export.panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        // The save panel needs Oriel active; the app the user was in gets the focus back afterwards.
        let previous = NSWorkspace.shared.frontmostApplication.flatMap { $0 == NSRunningApplication.current ? nil : $0 }
        NSApplication.shared.activate()
        Task { @MainActor [weak self] in
            let response = await export.panel.begin()
            previous?.activate()
            guard let self, !isClosed else { return }
            exportPanel = nil
            guard response == .OK, let url = export.panel.url else {
                panel.makeKey()
                return
            }
            do {
                try EditorExporter.write(session.document, format: export.format, to: url, effects: session.effects)
                Toast.show("Saved", symbol: "square.and.arrow.down", on: panel.screen)
                close()
            } catch {
                let path = url.path
                let reason = error.localizedDescription
                log.error("Saving an instant capture to \(path, privacy: .private) failed: \(reason, privacy: .public)")
                NSAlert(error: error).runModal()
                panel.makeKey()
            }
        }
    }

    func upload() {
        guard let onUpload, let image = session.flattenedImage() else {
            NSSound.beep()
            return
        }
        onUpload(image)
        close()
    }

    /// Moves the session (annotations, tool, colour and undo history) to a full editor window.
    func openInEditor() {
        session.commitPendingEdits()
        let session = session
        let handOver = onOpenInEditor
        tearDown()
        handOver?(session)
    }

    /// Closes without keeping anything.
    func close() {
        session.cancelGesture()
        tearDown()
    }

    // MARK: - Private

    private func tearDown() {
        guard !isClosed else { return }
        isClosed = true
        stylePopover?.close()
        restoreColorPanel()
        session.onChange = nil
        session.showSmartPreview([])
        canvas.commandHandler = nil
        panel.commandHandler = nil
        panel.removeChildWindow(toolbarPanel)
        toolbarPanel.orderOut(nil)
        panel.orderOut(nil)
        canvas.removeFromSuperview()
        onClose?(self)
    }

    private func sessionDidChange() {
        canvas.sessionDidChange()
        toolbar.update(tool: session.tool, color: session.color, canUndo: session.canUndo, canRedo: session.canRedo)
        (stylePopover?.contentViewController as? InstantStyleController)?.refresh()
        if let window = canvas.window, window.isKeyWindow {
            InstantContentView.cursor(for: session.tool).set()
        }
    }

    private func makeToolbar(showsUpload: Bool) -> InstantToolbar {
        let toolbar = InstantToolbar(
            showsUpload: showsUpload,
            selectTool: { [weak self] tool in self?.session.selectTool(tool) },
            showStyle: { [weak self] anchor in self?.showStyle(from: anchor) },
            perform: { [weak self] action in self?.run(action) }
        )
        self.toolbar = toolbar
        toolbar.update(tool: session.tool, color: session.color, canUndo: session.canUndo, canRedo: session.canRedo)
        return toolbar
    }

    private func showStyle(from anchor: NSView) {
        if let stylePopover, stylePopover.isShown {
            stylePopover.close()
            return
        }
        let controller = InstantStyleController(session: session)
        controller.onChange = { [weak self] in self?.sessionDidChange() }
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
        stylePopover = popover
        raiseColorPanel()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: placement.toolbarPosition == .above ? .maxY : .minY)
    }

    /// The colour panel floats at its normal level, which is below this panel; while the capture is open, it floats
    /// above it, and goes back afterwards.
    private func raiseColorPanel() {
        guard colorPanelLevel == nil else { return }
        let colorPanel = NSColorPanel.shared
        colorPanelLevel = colorPanel.level
        colorPanel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    }

    private func restoreColorPanel() {
        guard let level = colorPanelLevel else { return }
        if NSColorPanel.sharedColorPanelExists {
            NSColorPanel.shared.level = level
        }
        colorPanelLevel = nil
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_: Notification) {
        stylePopover = nil
        if !isClosed {
            panel.makeKey()
        }
    }

    /// The displays as Instant Capture's placement needs them.
    static func screens() -> [InstantPlacement.Screen] {
        NSScreen.screens.map { InstantPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame, scale: $0.backingScaleFactor) }
    }
}
