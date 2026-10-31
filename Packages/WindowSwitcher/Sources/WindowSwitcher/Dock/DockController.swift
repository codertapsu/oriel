import AppKit
import OrielCore
import os
import SharedUI

/// Window previews when the pointer rests on a Dock icon, and window counts on Dock icons (PLAN §7.1.12), from the
/// switcher's store. It reads the Dock through `DockAccessibility` and reacts to events only: the Dock's hover and icon
/// notifications, the store's snapshots, the Dock's preferences file, screen changes, app activations and clicks. Every
/// delay is a one-shot sleep that the next event replaces (CLAUDE.md rule 3).
final class DockController {
    /// After an icon is added or removed, or the Dock's settings change, the Dock moves its icons into place.
    static let settleDelay: Duration = .milliseconds(700)
    /// After the pointer leaves the Dock, it is read again for icons the user dragged to another place.
    static let leaveDelay: Duration = .milliseconds(400)

    private let store: WindowStore
    private let source: any WindowSource
    private let thumbnails: ThumbnailService
    private let panel = DockPreviewPanel()
    private let overlay = DockBadgeOverlay()
    private let preferencesWatcher = DockPreferencesWatcher()
    private let icons = AppIconCache()
    private let log = Log.logger("switcher")

    private var showsPreviews = false
    private var showsCounts = false
    private var tileWidth: CGFloat = 220
    private var dock: DockAccessibility?
    private var machine = DockHoverMachine()
    private var entries: [WindowEntry] = []
    private var layout: DockLayout?
    private var preferences = DockPreferences()
    /// Whether the pointer is on any icon of the Dock.
    private var isPointerInDock = false
    /// While the Dock moves its icons into place, the counts step aside.
    private var isSettling = false
    private var hoverReads = 0
    private var bundleIDs: [URL: String] = [:]
    private var eventTask: Task<Void, Never>?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var clickMonitor: Any?
    private var moveMonitor: Any?
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    private var dockObservation: NSKeyValueObservation?

    init(store: WindowStore, source: any WindowSource, thumbnails: ThumbnailService) {
        self.store = store
        self.source = source
        self.thumbnails = thumbnails
        panel.onClick = { [weak self] entry in self?.focus(entry) }
        panel.onAction = { [weak self] entry, action in self?.perform(action, on: entry) }
        panel.onPointerInside = { [weak self] inside in
            guard let self else { return }
            apply(machine.handle(inside ? .pointerEnteredPanel : .pointerLeftPanel))
        }
    }

    var isRunning: Bool {
        dock != nil
    }

    /// The windows the preview shows, kept through memory-pressure purges.
    var visibleWindowIDs: Set<UInt32> {
        panel.isVisible ? panel.windowIDs : []
    }

    /// Turns the previews and the counts on or off; with neither, nothing of it runs.
    func apply(showsPreviews: Bool, showsCounts: Bool, tileWidth: CGFloat) {
        self.showsPreviews = showsPreviews
        self.showsCounts = showsCounts
        self.tileWidth = tileWidth
        guard showsPreviews || showsCounts else {
            stop()
            return
        }
        if dock == nil {
            start()
        }
        if !showsPreviews {
            apply(machine.handle(.dismissed))
        }
        refreshBadges()
    }

    /// A new store snapshot: the counts and an open preview follow it.
    func update(entries: [WindowEntry]) {
        self.entries = entries
        guard isRunning else { return }
        icons.prune(keeping: Set(entries.map(\.info.pid)))
        refreshBadges()
        if panel.isVisible, let shown = machine.shown {
            showPreview(for: shown, isNew: false)
        }
    }

    /// Hides the preview, as when the switcher opens.
    func hidePreview() {
        apply(machine.handle(.dismissed))
    }

    /// Removes every observer, the panel and the counts.
    func stop() {
        guard let dock else { return }
        self.dock = nil
        for task in [eventTask, showTask, hideTask, layoutTask, thumbnailTask] {
            task?.cancel()
        }
        eventTask = nil
        showTask = nil
        hideTask = nil
        layoutTask = nil
        thumbnailTask = nil
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        dockObservation?.invalidate()
        dockObservation = nil
        preferencesWatcher.stop()
        stopMonitors()
        panel.hide()
        overlay.hide()
        machine = DockHoverMachine()
        layout = nil
        isPointerInDock = false
        isSettling = false
        icons.removeAll()
        Task { await dock.stop() }
    }

    // MARK: Following the Dock

    private func start() {
        let dock = DockAccessibility()
        self.dock = dock
        preferences = DockPreferences.current()
        eventTask = Task { [weak self] in
            for await event in dock.events {
                self?.handle(event)
            }
        }
        connect(dock)
        observe(NSWorkspace.didActivateApplicationNotification, on: NSWorkspace.shared.notificationCenter) { [weak self] in
            self?.appActivated()
        }
        observe(NSApplication.didChangeScreenParametersNotification, on: .default) { [weak self] in
            self?.scheduleLayout(after: Self.settleDelay, hidingCounts: true)
        }
        preferencesWatcher.start { [weak self] in
            guard let self else { return }
            preferences = DockPreferences.current()
            scheduleLayout(after: Self.settleDelay, hidingCounts: true)
        }
        // A Dock that quits (`killall Dock`, a crash) comes back as another process, which is observed instead.
        dockObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
            Task { @MainActor in self?.reconnectIfTheDockRestarted() }
        }
    }

    /// Observes the running Dock, then reads its icons; nothing once the features have stopped.
    private func connect(_ dock: DockAccessibility) {
        guard let pid = Self.dockPID() else { return }
        Task { [weak self] in
            guard self?.dock === dock else { return }
            await dock.start(pid: pid)
            await self?.readLayout()
        }
    }

    private func reconnectIfTheDockRestarted() {
        guard let dock else { return }
        let current = Self.dockPID()
        Task { [weak self] in
            // Checked after the await too: the features may have stopped meanwhile.
            guard await dock.pid != current, let self, self.dock === dock else { return }
            log.notice("observing the Dock again")
            connect(dock)
        }
    }

    private static func dockPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: DockAccessibility.bundleIdentifier).first?.processIdentifier
    }

    private func observe(_ name: Notification.Name, on center: NotificationCenter, _ handler: @escaping @MainActor @Sendable () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append((center, token))
    }

    private func handle(_ event: DockEvent) {
        switch event {
        case .hoverChanged:
            readHover()
        case .itemsChanged:
            checkForMovedIcons()
        }
    }

    /// An icon may have been added or removed: when the icons are not where they were read, the Dock is moving them, and
    /// the counts step aside until it is done. Notifications that move nothing change nothing.
    private func checkForMovedIcons() {
        guard let dock else { return }
        Task { [weak self] in
            let fresh = await dock.layout(displays: DisplayDirectory.current().map(\.bounds))
            guard let self, self.dock === dock, fresh?.items.map(\.frame) != layout?.items.map(\.frame) else { return }
            scheduleLayout(after: Self.settleDelay, hidingCounts: true)
        }
    }

    /// Reads the icon under the pointer; of reads that overlap, only the newest counts.
    private func readHover() {
        guard let dock else { return }
        hoverReads += 1
        let read = hoverReads
        Task { [weak self] in
            let item = await dock.hoveredItem()
            guard let self, self.dock === dock, read == hoverReads else { return }
            hover(item)
        }
    }

    private func hover(_ item: DockItem?) {
        let wasInDock = isPointerInDock
        isPointerInDock = item != nil
        if showsPreviews {
            let app = item.flatMap { $0.kind == .application && !windows(for: $0).isEmpty ? $0 : nil }
            apply(machine.handle(.hovered(app)))
        }
        guard wasInDock != isPointerInDock else { return }
        if isPointerInDock, preferences.hidesAutomatically {
            // The Dock slides out first; its icons are read where they come to rest.
            scheduleLayout(after: .milliseconds(300), hidingCounts: false)
        } else if !isPointerInDock {
            scheduleLayout(after: Self.leaveDelay, hidingCounts: false)
        }
        refreshBadges()
    }

    private func appActivated() {
        guard panel.isVisible else { return }
        apply(machine.handle(.dismissed))
    }

    private func scheduleLayout(after delay: Duration, hidingCounts: Bool) {
        guard dock != nil else { return }
        if hidingCounts {
            isSettling = true
            refreshBadges()
        }
        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.readLayout()
        }
    }

    private func readLayout() async {
        guard let dock else { return }
        let fresh = await dock.layout(displays: DisplayDirectory.current().map(\.bounds))
        guard self.dock === dock else { return }
        layout = fresh
        isSettling = false
        refreshBadges()
    }

    // MARK: Windows per icon

    private func windowMap(for items: [DockItem]) -> [Int: [WindowEntry]] {
        var ids: [Int: String] = [:]
        for (index, item) in items.enumerated() where item.kind == .application {
            ids[index] = item.url.flatMap(bundleID(of:))
        }
        let wanted = Set(ids.values)
        let processes = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.bundleIdentifier.map(wanted.contains) == true }
            .sorted { ($0.launchDate ?? .distantFuture, $0.processIdentifier) < ($1.launchDate ?? .distantFuture, $1.processIdentifier) }
            .compactMap { app in app.bundleIdentifier.map { DockWindowMap.Process(pid: app.processIdentifier, bundleID: $0) } }
        return DockWindowMap.windows(for: items, bundleIDs: ids, processes: processes, entries: entries)
    }

    private func windows(for item: DockItem) -> [WindowEntry] {
        if let layout, let index = layout.index(of: item) {
            return windowMap(for: layout.items)[index] ?? []
        }
        return windowMap(for: [item])[0] ?? []
    }

    private func bundleID(of url: URL) -> String? {
        if let known = bundleIDs[url] {
            return known
        }
        let id = Bundle(url: url)?.bundleIdentifier
        bundleIDs[url] = id
        return id
    }

    // MARK: Counts

    private func refreshBadges() {
        guard showsCounts, let layout, !isSettling, preferences.showsCounts(isHovering: isPointerInDock) else {
            overlay.hide()
            return
        }
        let windows = windowMap(for: layout.items)
        let badges = layout.items.indices.compactMap { index -> DockBadgeOverlay.Badge? in
            guard let text = DockBadgeLayout.text(for: windows[index]?.count ?? 0) else { return nil }
            return DockBadgeOverlay.Badge(text: text, itemFrame: layout.items[index].frame)
        }
        overlay.show(badges, edge: layout.edge)
    }

    // MARK: Preview

    private func apply(_ effects: [DockHoverMachine.Effect]) {
        for effect in effects {
            switch effect {
            case let .show(item):
                showPreview(for: item, isNew: true)
            case .hide:
                closePreview()
            case let .scheduleShow(item, delay):
                showTask?.cancel()
                showTask = Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled, let self else { return }
                    apply(machine.handle(.showDelayElapsed(item)))
                }
            case let .scheduleHide(delay):
                hideTask?.cancel()
                hideTask = Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled, let self else { return }
                    apply(machine.handle(.hideDelayElapsed))
                }
            case .cancelScheduledShow:
                showTask?.cancel()
                showTask = nil
            case .cancelScheduledHide:
                hideTask?.cancel()
                hideTask = nil
            }
        }
    }

    /// Shows the icon's windows next to it; `isNew` when it is another app's, which captures them afresh.
    private func showPreview(for item: DockItem, isNew: Bool) {
        let windows = windows(for: item)
        guard let first = windows.first, let screen = ScreenLocator.screen(containing: item.frame) else {
            apply(machine.handle(.emptied))
            return
        }
        let edge = layout?.edge ?? DockLayout.edge(nearest: item.frame, on: ScreenLocator.cgFrame(of: screen))
        let visible = screen.visibleFrame
        let available = CGSize(
            width: visible.width - 2 * DockPreviewLayout.margin, height: visible.height - 2 * DockPreviewLayout.margin
        )
        let metrics = LayoutMetrics.thumbnails(maximumTileWidth: tileWidth)
        let grid = DockPreviewLayout.make(count: windows.count, tileWidth: tileWidth, edge: edge, available: available, metrics: metrics)
        let frame = DockPreviewLayout.panelFrame(
            size: grid.panelSize, icon: ScreenLocator.cocoaRect(fromCG: item.frame), edge: edge, visibleFrame: visible
        )
        let displays = DisplayDirectory.current()
        let items = SwitcherItemBuilder.items(
            from: windows, style: .thumbnails, query: "", displayNumbers: DisplayInfo.numbers(for: displays),
            panelDisplayID: ScreenLocator.displayID(of: screen)
        )
        let icon = icons.icon(for: first.info.pid, bundleID: first.info.bundleID)
        panel.show(items, title: item.title.isEmpty ? first.info.appName : item.title, icon: icon, layout: grid, frame: frame)
        startMonitors()
        requestThumbnails(for: Array(items.prefix(grid.count)), grid: grid, scale: screen.backingScaleFactor, isNew: isNew)
    }

    private func closePreview() {
        panel.hide()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        stopMonitors()
    }

    /// Cached thumbnails at once, then fresh captures for a new preview; nothing without Screen Recording, when the tiles
    /// keep the app's icon.
    private func requestThumbnails(for items: [SwitcherItem], grid: DockPreviewLayout, scale: CGFloat, isNew: Bool) {
        thumbnailTask?.cancel()
        guard !items.isEmpty, CGPreflightScreenCaptureAccess() else { return }
        let caption = LayoutMetrics.thumbnails(maximumTileWidth: 0).captionHeight
        let box = CGSize(width: (grid.tileSize.width - 12) * scale, height: (grid.tileSize.height - caption - 6) * scale)
        let requests = items.map { item in
            let size = item.entry.info.frame.size
            return ThumbnailRequest(
                windowID: item.id,
                pixelSize: ThumbnailRequest.fittedSize(window: CGSize(width: size.width * scale, height: size.height * scale), in: box)
            )
        }
        let thumbnails = thumbnails
        let ids = Set(items.map(\.id))
        thumbnailTask = Task { [weak self] in
            if isNew {
                await thumbnails.beginSession(windowIDs: ids)
            }
            for await result in await thumbnails.thumbnails(for: requests) {
                guard !Task.isCancelled else { break }
                self?.panel.setThumbnail(result.image, for: result.windowID)
            }
        }
    }

    private func focus(_ entry: WindowEntry) {
        apply(machine.handle(.dismissed))
        let source = source
        let store = store
        Task {
            if await source.focus(entry) {
                await store.noteFocused(entry.id)
            }
        }
    }

    private func perform(_ action: TileAction, on entry: WindowEntry) {
        let source = source
        Task {
            switch action {
            case .close:
                _ = await source.perform(.close, on: entry)
            case .minimize, .restore:
                _ = entry.info.isMinimized ? await source.setMinimized(false, window: entry) : await source.perform(.minimize, on: entry)
            case .toggleFullScreen:
                _ = await source.perform(.toggleFullScreen, on: entry)
            }
        }
    }

    /// Only while the preview shows: a click anywhere but the panel (on the Dock icon, in another app) dismisses it, like
    /// a menu, and the pointer away from both the Dock and the panel hides it, in case the Dock did not say it left.
    private func startMonitors() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.apply(self.machine.handle(.dismissed))
            }
        }
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
    }

    private func stopMonitors() {
        for monitor in [clickMonitor, moveMonitor].compactMap(\.self) {
            NSEvent.removeMonitor(monitor)
        }
        clickMonitor = nil
        moveMonitor = nil
    }

    private func pointerMoved() {
        guard panel.isVisible, machine.hovered != nil, let layout else { return }
        let location = NSEvent.mouseLocation
        let dock = layout.items.reduce(layout.frame) { $0.union($1.frame) }
        guard !ScreenLocator.cocoaRect(fromCG: dock).insetBy(dx: -6, dy: -6).contains(location), !panel.frame.contains(location) else {
            return
        }
        apply(machine.handle(.hovered(nil)))
    }
}
