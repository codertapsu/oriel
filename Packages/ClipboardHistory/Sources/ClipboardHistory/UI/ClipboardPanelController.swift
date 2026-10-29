import AppKit
import OrielCore
import SharedUI

/// The Clipboard History panel (PLAN §7.9): a floating, non-activating panel that takes typing for its search field
/// while the app the user was in stays the active app, so a pasted item lands in that app's focused field. The list is
/// on the left, the selected item's preview on the right, and the paste button names the app it pastes into.
final class ClipboardPanelController: NSObject {
    /// The type that marks a row being dragged within the list.
    static let rowType = NSPasteboard.PasteboardType("com.codertapsu.oriel.clipboard-row")

    /// Opens Settings at Clipboard History.
    var openSettings: (() -> Void)?
    /// Called after the panel changed the history (deleted, pinned, moved, pasted).
    var onHistoryChanged: (() -> Void)?

    let recorder: ClipboardRecorder
    let settings: SettingsStore
    let permissions: any PermissionChecking
    let model = ClipboardPanelModel()
    let content = ClipboardPanelView(frame: CGRect(origin: .zero, size: ClipboardPanelView.size))
    let icons = ClipboardIconCache()
    let panel = FloatingPanel(contentRect: CGRect(origin: .zero, size: ClipboardPanelView.size), level: .modalPanel)
    let tableMenu = NSMenu()
    /// The app in front when the panel opened: where Paste goes.
    var target: NSRunningApplication?
    /// Deletions Undo can still take back, newest last.
    var deletions: [ClipboardDeletion] = []
    var previewTask: Task<Void, Never>?
    var previewedItem: ClipboardItem?
    var loadingThumbnails: Set<UUID> = []
    /// Keyboard selection: the row the arrows move from, and the far end of a ⇧-arrow range.
    var cursorRow: Int?
    var anchorRow: Int?
    var isMovingCursor = false
    private var resignObserver: (any NSObjectProtocol)?

    init(recorder: ClipboardRecorder, settings: SettingsStore, permissions: any PermissionChecking) {
        self.recorder = recorder
        self.settings = settings
        self.permissions = permissions
        super.init()
        panel.allowsKey = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = content
        // A fixed size: nothing a preview shows may grow the panel.
        panel.contentMinSize = ClipboardPanelView.size
        panel.contentMaxSize = ClipboardPanelView.size
        panel.setAccessibilityLabel("Clipboard History")
        connectViews()
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            // Clicking another app, or anywhere outside, closes the panel, as Spotlight does.
            MainActor.assumeIsolated { self?.close() }
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    /// Opens the panel over `target`, the app in front, on the screen under the pointer.
    func show(target: NSRunningApplication?) {
        self.target = target
        recorder.checkNow()
        model.query = ""
        model.filter = .all
        content.searchField.stringValue = ""
        content.filterButton.selectItem(at: 0)
        content.showUndo(nil)
        deletions = []
        previewedItem = nil
        Task {
            await model.update(recorder.store.index())
            reload(selecting: [])
            place()
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(content.searchField)
        }
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        previewTask?.cancel()
        previewTask = nil
        if !deletions.isEmpty {
            deletions = []
            let store = recorder.store
            Task { await store.emptyTrash() }
        }
    }

    /// The history changed while the panel shows: list it again, keeping the selection.
    func refresh() {
        guard panel.isVisible else { return }
        Task {
            await model.update(recorder.store.index())
            reload(selecting: selectedItems.map(\.id))
        }
    }

    /// Reloads the list and selects `ids`, else the first of what the panel opens on.
    func reload(selecting ids: [UUID], fallbackRow: Int? = nil) {
        content.table.reloadData()
        var rows = IndexSet(ids.compactMap(model.row(of:)))
        if rows.isEmpty, let row = fallbackRow.flatMap(model.nearestItemRow(to:)) ?? model.initialRow {
            rows = [row]
        }
        content.table.selectRowIndexes(rows, byExtendingSelection: false)
        if let first = rows.first {
            // Opening on the newest copy still shows the pinned items above it when they fit.
            if first == model.initialRow {
                content.table.scrollRowToVisible(0)
            }
            content.table.scrollRowToVisible(first)
        }
        updateChrome()
        updatePreview()
    }

    var selectedItems: [ClipboardItem] {
        content.table.selectedRowIndexes.compactMap(model.item(at:))
    }

    // MARK: Chrome

    /// Brings the footer, banner and empty-list text up to date with the selection and state.
    func updateChrome() {
        let items = selectedItems
        let pinned = Set(model.index.pinned.map(\.id))
        let allPinned = !items.isEmpty && items.allSatisfy { pinned.contains($0.id) }
        content.pinButton.image = NSImage(systemSymbolName: allPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        content.pinButton.toolTip = allPinned ? "Unpin (⌘P)" : "Pin (⌘P)"
        content.pinButton.isEnabled = !items.isEmpty
        content.deleteButton.isEnabled = !items.isEmpty
        content.copyButton.isEnabled = !items.isEmpty
        content.pasteButton.isEnabled = !items.isEmpty
        content.pasteButton.title = pasteTitle(count: items.count)
        content.pasteButton.image = target.flatMap(\.icon).map(Self.small)
        if content.undoButton.isHidden {
            content.statusField.stringValue = statusText(selected: items.count)
        }
        content.showBanner(bannerMessage)
        let empty = model.rows.isEmpty
        content.emptyField.isHidden = !empty
        content.emptyField.stringValue = model.index.count == 0
            ? "Nothing here yet.\nWhat you copy appears here, newest first."
            : "Nothing matches “\(model.query)”."
    }

    private func pasteTitle(count: Int) -> String {
        let what = count > 1 ? "Paste \(count) Items" : "Paste"
        guard let name = target?.localizedName, target != NSRunningApplication.current else { return what }
        return "\(what) to \(name)"
    }

    private func statusText(selected: Int) -> String {
        if selected > 1 {
            return "\(selected) selected"
        }
        let shown = model.itemRows.count
        let total = model.index.count
        return model.isFiltering ? "\(shown) of \(ClipboardFormat.count(total, "item"))" : ClipboardFormat.count(total, "item")
    }

    /// The one thing that most needs saying, if anything.
    private var bannerMessage: ClipboardBannerView.Message? {
        if recorder.isPaused {
            return .init(symbol: "pause.circle.fill", text: "Clipboard History is paused: nothing you copy is kept.", action: "Resume")
        }
        let missed = recorder.missedCopies > 0 ? " \(ClipboardFormat.count(recorder.missedCopies, "copy", "copies")) missed." : ""
        switch recorder.access {
        case .denied:
            return .init(
                symbol: "hand.raised.fill",
                text: "Paste from Other Apps is set to Deny, so only Oriel's own copies are kept.\(missed)",
                action: "Open Settings"
            )
        case .asks:
            return .init(
                symbol: "exclamationmark.triangle.fill",
                text: "macOS asks before Oriel reads what you copy. Set Oriel to Allow in Paste from Other Apps.\(missed)",
                action: "Open Settings"
            )
        case .notAsked:
            // Until the first copy from another app is kept, say what macOS is about to ask.
            let own = Bundle.main.bundleIdentifier
            if !model.index.all.contains(where: { $0.sourceBundleID != own }) {
                return .init(
                    symbol: "info.circle.fill",
                    text: "When you copy in another app, macOS asks whether Oriel may paste from it. Choose Allow to keep that copy here.",
                    action: nil
                )
            }
        case .allowed:
            break
        }
        if permissions.status(of: .accessibility) != .granted {
            return .init(
                symbol: "keyboard",
                text: "Pasting needs Accessibility. Until then Oriel copies the item and you press ⌘V.",
                action: "Open Settings"
            )
        }
        return nil
    }

    func bannerAction() {
        if recorder.isPaused {
            recorder.setPaused(false)
        } else if recorder.access == .denied || recorder.access == .asks {
            close()
            permissions.openSystemSettings(for: .pasteboard)
        } else {
            close()
            permissions.openSystemSettings(for: .accessibility)
        }
        updateChrome()
    }

    // MARK: Preview

    func updatePreview() {
        let items = selectedItems
        guard items.count == 1, let item = items.first else {
            previewTask?.cancel()
            previewedItem = nil
            let text = items.isEmpty ? (model.rows.isEmpty ? "" : "Select an item to see it here.") : "\(items.count) items selected"
            content.preview.showPlaceholder(text)
            return
        }
        guard item != previewedItem else { return }
        previewedItem = item
        previewTask?.cancel()
        let store = recorder.store
        previewTask = Task {
            let detail = await Task.detached(priority: .userInitiated) { ClipboardPreviewDetail.load(item, from: store) }.value
            guard !Task.isCancelled, previewedItem == item else { return }
            content.preview.show(item, detail: detail, icons: icons)
        }
    }

    /// An image item's thumbnail, loaded in the background the first time; the row updates when it arrives.
    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard item.hasThumbnail else { return nil }
        if let image = icons.thumbnail(for: item.id) {
            return image
        }
        guard loadingThumbnails.insert(item.id).inserted else { return nil }
        let store = recorder.store
        let id = item.id
        Task {
            let image = await Task.detached(priority: .userInitiated) { store.thumbnail(of: id) }.value
            loadingThumbnails.remove(id)
            guard let image else { return }
            let thumbnail = NSImage(cgImage: image, size: .zero)
            icons.setThumbnail(thumbnail, for: id)
            guard let row = model.row(of: id) else { return }
            let view = content.table.view(atColumn: 0, row: row, makeIfNecessary: false) as? ClipboardRowView
            if view?.itemID == id {
                view?.setThumbnail(thumbnail)
            }
        }
        return nil
    }

    // MARK: Setup

    /// On the screen under the pointer, a little above its middle, where Spotlight sits.
    private func place() {
        guard let screen = ScreenLocator.screenUnderMouse else { return }
        let visible = screen.visibleFrame
        let size = ClipboardPanelView.size
        let origin = CGPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2 + visible.height * 0.08).rounded()
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    private func connectViews() {
        let table = content.table
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClicked)
        table.registerForDraggedTypes([Self.rowType])
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.onKeyDown = { [weak self] event in self?.tableKeyDown(event) ?? false }
        tableMenu.delegate = self
        table.menu = tableMenu
        content.searchField.delegate = self
        content.filterButton.target = self
        content.filterButton.action = #selector(filterChanged)
        content.moreButton.menu?.delegate = self
        content.onKeyEquivalent = { [weak self] event in self?.handleKeyEquivalent(event) ?? false }
        content.onCancel = { [weak self] in self?.escape() }
        content.banner.onAction = { [weak self] in self?.bannerAction() }
        content.preview.onOpenLink = { [weak self] url in self?.open(url) }
        content.preview.onRevealFiles = { [weak self] urls in self?.reveal(urls) }
        for (button, action) in [
            (content.pinButton, #selector(pinClicked)),
            (content.deleteButton, #selector(deleteClicked)),
            (content.undoButton, #selector(undoClicked)),
            (content.copyButton, #selector(copyClicked)),
            (content.pasteButton, #selector(pasteClicked)),
        ] {
            button.target = self
            button.action = action
        }
    }

    private static func small(_ icon: NSImage) -> NSImage {
        let copy = icon.copy() as? NSImage ?? icon
        copy.size = NSSize(width: 18, height: 18)
        return copy
    }
}
