import AppKit
import OrielCore

/// The Disk Space Analyzer window (PLAN §7.10): the sidebar with volumes, cloud locations and recent scans; the main
/// area with breadcrumbs, the view switcher and the views; the inspector; and a toolbar with the actions. Made when
/// the window opens and let go when it closes, so a closed window costs nothing.
final class DiskWindowController: NSWindowController, NSWindowDelegate {
    static let autosaveName = "OrielDiskAnalyzer"

    let model: DiskAnalyzerModel
    let split = NSSplitViewController()
    let sidebar: SidebarViewController
    let main: MainViewController
    let inspector: InspectorViewController
    /// Called when the window has closed.
    var onClose: (() -> Void)?
    let searchItem = NSSearchToolbarItem(itemIdentifier: .diskSearch)
    var toolbarItems: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    var operationSheet: OperationSheetController?
    var changesSheet: ChangesSheetController?
    /// The files Quick Look shows.
    var quickLookURLs: [URL] = []
    private var isOpen = true
    let log = Log.logger("disk")

    init(model: DiskAnalyzerModel) {
        self.model = model
        sidebar = SidebarViewController(model: model)
        main = MainViewController(model: model)
        inspector = InspectorViewController(model: model)
        let window = DiskWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Disk Space Analyzer"
        window.minSize = CGSize(width: 880, height: 540)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.delegate = self
        window.keyEquivalentHandler = { [weak self] in self?.handleKeyEquivalent($0) ?? false }
        sidebar.actions = self
        main.actions = self
        inspector.actions = self
        setUpSplit()
        window.contentViewController = split
        window.toolbar = makeToolbar()
        if !window.setFrameUsingName(Self.autosaveName) {
            window.setContentSize(CGSize(width: 1180, height: 760))
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
        model.undoManager = window.undoManager
        model.onMessage = { [weak self] message in self?.present(message) }
        ObservationLoop.run(while: { [weak self] in self?.isOpen == true }, render: { [weak self] in self?.render() })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setUpSplit() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 340
        sidebarItem.canCollapse = true
        let mainItem = NSSplitViewItem(viewController: main)
        mainItem.minimumThickness = 440
        let inspectorItem = NSSplitViewItem(inspectorWithViewController: inspector)
        inspectorItem.minimumThickness = 250
        inspectorItem.maximumThickness = 380
        inspectorItem.canCollapse = true
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(mainItem)
        split.addSplitViewItem(inspectorItem)
        split.splitView.autosaveName = "OrielDiskAnalyzerSplit"
    }

    func show() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        model.windowOpened()
    }

    func windowWillClose(_: Notification) {
        isOpen = false
        // A file operation the user started finishes on its own; only its sheet goes.
        if let sheet = operationSheet {
            window?.endSheet(sheet.panel)
            operationSheet = nil
        }
        model.windowClosed()
        onClose?()
    }

    // MARK: Following the model

    private func render() {
        updateToolbar()
        updateOperationSheet()
        updateQuickLook()
        if let window {
            window.subtitle = subtitle
        }
    }

    private var subtitle: String {
        switch model.content {
        case .scan, .scanning: model.target?.displayName ?? ""
        case let .volume(volume): volume.name
        case let .cloud(location): location.title
        case let .record(record): record.displayName
        case .welcome: ""
        }
    }

    private func updateOperationSheet() {
        guard let window else { return }
        if let operation = model.operation {
            if operationSheet == nil {
                let sheet = OperationSheetController(kind: operation.kind) { [weak self] in self?.model.cancelOperation() }
                operationSheet = sheet
                window.beginSheet(sheet.panel)
            }
            operationSheet?.update(operation.progress)
        } else if let sheet = operationSheet {
            window.endSheet(sheet.panel)
            operationSheet = nil
        }
    }

    /// Shows a message from the model as a sheet.
    func present(_ message: DiskAnalyzerModel.Message) {
        let alert = NSAlert()
        alert.messageText = message.title
        alert.informativeText = message.text
        if let window, window.isVisible, window.attachedSheet == nil {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
