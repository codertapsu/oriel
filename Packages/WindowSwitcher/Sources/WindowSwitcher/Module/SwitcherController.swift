import AppKit
import CoreGraphics
import Hotkeys
import OrielCore
import os
import SharedUI

/// Ties the event tap to the state machine, the session model and the panels (PLAN §7.1.4, §7.1.10).
///
/// The tap callback runs the state machine and updates the session model synchronously: table lookups,
/// filtering and layout arithmetic, well under a millisecond. Showing panels, thumbnails, the preview and
/// focusing happen on the next main-actor turn, so the callback never waits on AppKit, ScreenCaptureKit or
/// Accessibility.
final class SwitcherController {
    /// The panel is opening: the Dock's preview steps aside.
    var onOpen: (() -> Void)?

    private let store: WindowStore
    private let source: any WindowSource
    private let thumbnails: ThumbnailService
    private let panel = SwitcherPanelController()
    private let preview = PreviewPanelController()
    private let icons = AppIconCache()
    private let log = Log.logger("switcher")

    private var configuration: SwitcherConfiguration
    /// The keys that can open a shortcut, so every other keystroke costs one set lookup.
    private var triggerKeys: Set<UInt16>
    private var machine: SwitcherStateMachine
    private var gestures = GestureRecognizer()
    private var entries: [WindowEntry] = []
    private(set) var session: SwitcherSessionModel?
    private var nextToken = 0
    private var accessibilityObserver: (any NSObjectProtocol)?
    private var screenObserver: (any NSObjectProtocol)?
    /// Read once and again after each screen change, not in every tap callback.
    private var cachedDisplays: [DisplayInfo]?

    private var viewSyncScheduled = false
    private var presentedToken: Int?
    private var presentedVersion: Int?
    private var previewedWindowID: UInt32?
    private var canCapture = false
    private var preparation: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var outsideClickMonitor: Any?

    init(store: WindowStore, source: any WindowSource, thumbnails: ThumbnailService, configuration: SwitcherConfiguration) {
        self.store = store
        self.source = source
        self.thumbnails = thumbnails
        self.configuration = configuration
        triggerKeys = configuration.triggerKeys
        machine = SwitcherStateMachine(shortcuts: configuration.shortcuts)
        panel.onHover = { [weak self] index in self?.hover(index) }
        panel.onClick = { [weak self] index in self?.click(index) }
        panel.onAction = { [weak self] index, action in self?.tileAction(action, at: index) }
        // Reduce Transparency, Increase Contrast and Reduce Motion apply live (PLAN §7.1.9); the glass
        // background switches itself, the tiles are redrawn.
        accessibilityObserver = AccessibilityDisplay.observe { [weak self] _ in
            guard let self, session != nil else { return }
            session?.version += 1
            scheduleViewSync()
        }
        // A display that goes away may be the panel's: close rather than float on a missing screen.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.cachedDisplays = nil
                self.applyEffects(self.machine.cancel())
            }
        }
    }

    var isOpen: Bool {
        session != nil
    }

    /// The windows currently visible in the panel, for memory-pressure purges.
    var visibleWindowIDs: Set<UInt32> {
        Set(session?.items.map(\.id) ?? [])
    }

    func update(configuration: SwitcherConfiguration) {
        guard configuration != self.configuration else { return }
        if machine.isOpen {
            applyEffects(machine.cancel())
        }
        self.configuration = configuration
        triggerKeys = configuration.triggerKeys
        machine.shortcuts = configuration.shortcuts
    }

    /// A new store snapshot. While open, the panel follows it and keeps the selected window selected.
    func update(entries: [WindowEntry]) {
        self.entries = entries
        icons.prune(keeping: Set(entries.map(\.info.pid)))
        guard var session else { return }
        let selected = session.selectedItem?.id
        session.windows = session.filter.apply(to: entries, context: session.context)
        self.session = session
        rebuildItems(selectingWindow: selected)
        scheduleViewSync()
    }

    // MARK: Event tap

    /// The tap callback's handler. Returns in well under a millisecond (PLAN §7.1.4).
    func handle(_ event: TapEvent) -> TapDecision {
        switch event {
        case let .keyDown(keyCode, modifiers, isRepeat):
            if !machine.isOpen, triggerKeys.contains(keyCode) {
                prepareTrigger()
            }
            let characters = machine.isOpen ? KeyTranslator.characters(keyCode: keyCode, modifiers: modifiers) : nil
            return apply(machine.handle(.keyDown(keyCode: keyCode, modifiers: modifiers, isRepeat: isRepeat, characters: characters)))
        case let .keyUp(keyCode, modifiers):
            return apply(machine.handle(.keyUp(keyCode: keyCode, modifiers: modifiers)))
        case let .flagsChanged(modifiers):
            return apply(machine.handle(.flagsChanged(modifiers)))
        case let .gesture(touches):
            for gesture in gestures.feed(touches) {
                if case .began = gesture, !machine.isOpen {
                    prepareTrigger()
                }
                apply(machine.handle(.gesture(gesture)))
            }
            // The system and the front app still get every gesture frame.
            return .pass
        case .leftMouseDown:
            return .pass
        }
    }

    /// Opens shortcut `shortcutIndex` without a key press, in keep-open mode.
    func open(shortcutIndex: Int) {
        machine.isStickyKeysOn = StickyKeys.isEnabled
        applyEffects(machine.open(shortcutIndex: shortcutIndex))
    }

    func stop() {
        if machine.isOpen {
            applyEffects(machine.cancel())
        }
        closeSession()
        preparation?.cancel()
        panel.hide()
        preview.hide()
        icons.removeAll()
        if let accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver)
        }
        accessibilityObserver = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    // MARK: Model (synchronous)

    @discardableResult
    private func apply(_ transition: SwitcherTransition) -> TapDecision {
        applyEffects(transition.effects)
        return transition.decision
    }

    private func applyEffects(_ effects: [SwitcherEffect]) {
        guard !effects.isEmpty else { return }
        for effect in effects {
            applyModel(effect)
        }
        scheduleViewSync()
    }

    private func applyModel(_ effect: SwitcherEffect) {
        switch effect {
        case let .show(shortcutIndex):
            openSession(shortcutIndex: shortcutIndex)
        case let .select(index):
            session?.selection = index
        case let .search(query):
            session?.query = query
            rebuildItems(selectingIndex: 0)
        case let .commit(index):
            commit(index)
        case .cancel:
            closeSession()
        case let .act(action, index):
            perform(action, at: index)
        case let .quitApp(index):
            quitApp(at: index)
        }
    }

    /// The display Settings → Window Switcher → Show on names, else the one under the pointer.
    private func panelScreen(context: FilterContext) -> NSScreen? {
        let placement = configuration.placement
        let id = placement.display(
            pointer: ScreenLocator.screenUnderMouse.flatMap(ScreenLocator.displayID(of:)),
            activeWindow: placement == .activeWindow ? PanelPlacement.activeWindowDisplay(in: entries, context: context) : nil,
            main: NSScreen.screens.first.flatMap(ScreenLocator.displayID(of:))
        )
        return id.flatMap(ScreenLocator.screen(for:)) ?? ScreenLocator.screenUnderMouse ?? NSScreen.main
    }

    /// Sticky Keys and the exception list are read only when a trigger key arrives, not on every keystroke.
    private func prepareTrigger() {
        machine.isStickyKeysOn = StickyKeys.isEnabled
        machine.isSuppressed = configuration.exceptions.ignoresShortcuts(in: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func openSession(shortcutIndex: Int) {
        let displays = cachedDisplays ?? DisplayDirectory.current()
        cachedDisplays = displays
        var context = FilterContext(activePID: NSWorkspace.shared.frontmostApplication?.processIdentifier, displays: displays)
        guard configuration.shortcuts.indices.contains(shortcutIndex), let screen = panelScreen(context: context) else {
            applyEffects(machine.cancel())
            return
        }
        let shortcut = configuration.shortcuts[shortcutIndex]
        // "Current screen" filters mean the display the panel is on.
        context.screenDisplayID = ScreenLocator.displayID(of: screen)
        let style = shortcut.style ?? configuration.style
        nextToken += 1
        session = SwitcherSessionModel(
            token: nextToken,
            shortcutIndex: shortcutIndex,
            style: style,
            filter: shortcut.filter,
            grouping: shortcut.grouping,
            context: context,
            screen: screen,
            windows: shortcut.filter.apply(to: entries, context: context),
            hints: configuration.showsKeyHints ? KeyHint.windowActions(holding: shortcut.holdModifiers) : [],
            layout: LayoutCalculator.layout(
                count: 0, style: style, metrics: .forStyle(style, thumbnailWidth: configuration.thumbnailWidth),
                maximumSize: .zero, showsSearchBar: false
            ),
            displayNumbers: DisplayInfo.numbers(for: displays)
        )
        rebuildItems()
        startOutsideClickMonitor()
        onOpen?()
        let store = store
        Task { await store.refresh() }
    }

    private func rebuildItems(selectingIndex: Int? = nil, selectingWindow windowID: UInt32? = nil) {
        guard var session else { return }
        session.items = SwitcherItemBuilder.items(
            from: session.windows,
            style: session.style,
            query: session.query,
            displayNumbers: session.displayNumbers,
            panelDisplayID: session.context.screenDisplayID,
            grouping: session.grouping
        )
        session.groups = session.isGrouped ? SwitcherItemBuilder.groups(of: session.items) : []
        session.layout = LayoutCalculator.layout(
            count: session.items.count,
            style: session.style,
            metrics: .forStyle(session.style, thumbnailWidth: configuration.thumbnailWidth),
            maximumSize: LayoutCalculator.maximumPanelSize(forVisibleFrame: session.screen.visibleFrame.size),
            showsSearchBar: !session.query.isEmpty,
            groupStarts: session.isGrouped ? session.groups.map(\.items.lowerBound) : nil,
            showsHints: !session.hints.isEmpty
        )
        session.version += 1
        self.session = session
        let preferred = windowID.flatMap { id in session.items.firstIndex { $0.id == id } } ?? selectingIndex
        // Grouping moves the previous window away from the second place; the first selection follows it.
        let initial = session.isGrouped ? SwitcherItemBuilder.initialSelection(in: session.items, windows: session.windows) : nil
        let effects = machine.setItems(count: session.items.count, columns: session.layout.columns, selecting: preferred, initial: initial)
        for effect in effects {
            applyModel(effect)
        }
    }

    private func item(at index: Int) -> SwitcherItem? {
        guard let items = session?.items, items.indices.contains(index) else { return nil }
        return items[index]
    }

    private func commit(_ index: Int) {
        let target = item(at: index)?.entry
        closeSession()
        guard let target else { return }
        let source = source
        let store = store
        Task {
            if await source.focus(target) {
                await store.noteFocused(target.id)
            }
        }
    }

    private func closeSession() {
        guard session != nil else { return }
        session = nil
        stopOutsideClickMonitor()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        previewTask?.cancel()
        previewTask = nil
        previewedWindowID = nil
        let thumbnails = thumbnails
        Task { await thumbnails.endSession() }
    }

    private func perform(_ action: WindowAction, at index: Int) {
        guard let entry = item(at: index)?.entry else { return }
        let source = source
        Task { [weak self] in
            let done = if action == .minimize, entry.info.isMinimized {
                await source.setMinimized(false, window: entry)
            } else {
                await source.perform(action, on: entry)
            }
            if done, action == .close {
                self?.remove { $0.id == entry.id }
            }
        }
    }

    private func quitApp(at index: Int) {
        guard let pid = item(at: index)?.entry.info.pid else { return }
        let source = source
        Task { [weak self] in
            if await source.quit(pid: pid) {
                self?.remove { $0.info.pid == pid }
                self?.icons.forget(pid: pid)
            }
        }
    }

    /// Drops windows at once after an action, before the store's notification confirms it.
    private func remove(where predicate: (WindowEntry) -> Bool) {
        entries.removeAll(where: predicate)
        guard var session else { return }
        let selection = session.selection
        session.windows.removeAll(where: predicate)
        self.session = session
        rebuildItems(selectingIndex: selection)
        scheduleViewSync()
    }

    private func hover(_ index: Int) {
        applyEffects(machine.select(index))
    }

    private func click(_ index: Int) {
        applyEffects(machine.commit(at: index))
    }

    private func tileAction(_ action: TileAction, at index: Int) {
        switch action {
        case .close: perform(.close, at: index)
        case .minimize, .restore: perform(.minimize, at: index)
        case .toggleFullScreen: perform(.toggleFullScreen, at: index)
        }
    }

    /// A click in another app cancels, like clicking outside a menu. Installed only while open.
    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.applyEffects(self.machine.cancel())
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    // MARK: View (next main-actor turn)

    private func scheduleViewSync() {
        guard !viewSyncScheduled else { return }
        viewSyncScheduled = true
        Task { [weak self] in self?.syncView() }
    }

    private func syncView() {
        viewSyncScheduled = false
        guard let session else {
            panel.hide()
            preview.hide()
            presentedToken = nil
            presentedVersion = nil
            return
        }
        let isNewSession = presentedToken != session.token
        if isNewSession {
            startCaptureSession(for: session)
        }
        panel.render(session, icons: icons)
        if isNewSession || presentedVersion != session.version {
            requestThumbnails(for: session)
        }
        updatePreview(for: session)
        presentedToken = session.token
        presentedVersion = session.version
    }

    /// Screen Recording is checked once per opening; without it the switcher shows icons and titles only.
    private func startCaptureSession(for session: SwitcherSessionModel) {
        canCapture = CGPreflightScreenCaptureAccess()
        preparation?.cancel()
        guard canCapture, session.style == .thumbnails || configuration.showsPreview else {
            preparation = nil
            return
        }
        let thumbnails = thumbnails
        let ids = Set(session.windows.map(\.id))
        preparation = Task { await thumbnails.beginSession(windowIDs: ids) }
    }

    private func requestThumbnails(for session: SwitcherSessionModel) {
        thumbnailTask?.cancel()
        guard canCapture, session.style == .thumbnails, !session.items.isEmpty else { return }
        let scale = session.screen.backingScaleFactor
        let box = SwitcherPanelController.imageSize(of: session.layout, style: session.style)
        let pixelBox = CGSize(width: box.width * scale, height: box.height * scale)
        let requests = Self.visibleFirst(session).map { item in
            let frame = item.entry.info.frame.size
            return ThumbnailRequest(
                windowID: item.id,
                pixelSize: ThumbnailRequest.fittedSize(
                    window: CGSize(width: frame.width * scale, height: frame.height * scale),
                    in: pixelBox
                )
            )
        }
        let thumbnails = thumbnails
        let preparation = preparation
        thumbnailTask = Task { [weak self] in
            await preparation?.value
            for await result in await thumbnails.thumbnails(for: requests) {
                self?.panel.setThumbnail(result.image, for: result.windowID)
            }
        }
    }

    /// The rows around the selection first, then the rest in order (PLAN §7.1.7).
    private static func visibleFirst(_ session: SwitcherSessionModel) -> [SwitcherItem] {
        let layout = session.layout
        let selectedRow = session.selection / max(layout.columns, 1)
        let firstRow = max(0, selectedRow - layout.visibleRows + 1)
        let visible = (firstRow * layout.columns) ..< min((firstRow + layout.visibleRows) * layout.columns, session.items.count)
        return Array(session.items[visible]) + session.items.indices.filter { !visible.contains($0) }.map { session.items[$0] }
    }

    private func updatePreview(for session: SwitcherSessionModel) {
        guard configuration.showsPreview, canCapture, let item = session.selectedItem else {
            previewTask?.cancel()
            previewedWindowID = nil
            preview.hide()
            return
        }
        guard previewedWindowID != item.id else { return }
        previewedWindowID = item.id
        previewTask?.cancel()
        let windowID = item.id
        let frame = item.entry.info.frame
        let scale = (ScreenLocator.screen(containing: frame) ?? session.screen).backingScaleFactor
        let pixelSize = CGSize(width: frame.width * scale, height: frame.height * scale)
        let thumbnails = thumbnails
        let preparation = preparation
        previewTask = Task { [weak self] in
            if let cached = await thumbnails.cachedThumbnail(for: windowID), !Task.isCancelled {
                self?.preview.show(cached.image, windowID: windowID, frame: frame, isStale: true)
            } else if !Task.isCancelled {
                self?.preview.hide()
            }
            await preparation?.value
            guard !Task.isCancelled, let image = await thumbnails.preview(for: windowID, pixelSize: pixelSize), !Task.isCancelled else {
                return
            }
            self?.preview.show(image, windowID: windowID, frame: frame, isStale: false)
        }
    }
}
