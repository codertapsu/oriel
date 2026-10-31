import AppKit
import OrielCore
import os
import SharedUI

/// Window previews when the pointer rests on a Dock icon, and window counts on Dock icons (PLAN §7.1.12), from the
/// switcher's store. It reads the Dock through `DockAccessibility` and reacts to events only: the Dock's hover and icon
/// notifications, the store's snapshots, the Dock's preferences file, screen and Space changes, app activations and clicks.
/// Every delay is a one-shot sleep that the next event replaces (CLAUDE.md rule 3).
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
    private var layoutSchedule = DockLayoutSchedule()
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
    /// A Dock that did not answer while it was still launching, watched until it has finished.
    private var launchObservation: NSKeyValueObservation?

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
        launchObservation?.invalidate()
        launchObservation = nil
        preferencesWatcher.stop()
        stopMonitors()
        panel.hide()
        overlay.hide()
        machine = DockHoverMachine()
        layout = nil
        layoutSchedule = DockLayoutSchedule()
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
        // Back from a full-screen Space, where the Dock hides, nothing else reads it again.
        observe(NSWorkspace.activeSpaceDidChangeNotification, on: NSWorkspace.shared.notificationCenter) { [weak self] in
            self?.scheduleLayout(after: Self.settleDelay, hidingCounts: false)
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

    /// Observes the running Dock, then reads its icons; nothing once the features have stopped. A Dock that has just
    /// started (after `killall Dock`) may not answer yet: it is asked again once it has finished launching.
    private func connect(_ dock: DockAccessibility) {
        guard let app = Self.runningDock() else { return }
        launchObservation = nil
        Task { [weak self] in
            guard self?.dock === dock else { return }
            let answered = await dock.start(pid: app.processIdentifier)
            guard let self, self.dock === dock else { return }
            if !answered, !app.isFinishedLaunching {
                connectWhenLaunched(app, dock: dock)
            }
            scheduleLayout(after: .zero, hidingCounts: false)
        }
    }

    /// Connects again, once, when `app` (the Dock) has finished launching.
    private func connectWhenLaunched(_ app: NSRunningApplication, dock: DockAccessibility) {
        launchObservation = app.observe(\.isFinishedLaunching, options: [.initial, .new]) { [weak self] app, _ in
            guard app.isFinishedLaunching else { return }
            Task { @MainActor [weak self] in
                guard let self, self.dock === dock, launchObservation != nil else { return }
                launchObservation = nil
                connect(dock)
            }
        }
    }

    private func reconnectIfTheDockRestarted() {
        guard let dock else { return }
        let current = Self.runningDock()?.processIdentifier
        Task { [weak self] in
            // Checked after the await too: the features may have stopped meanwhile.
            guard await dock.pid != current, let self, self.dock === dock else { return }
            log.notice("observing the Dock again")
            connect(dock)
        }
    }

    private static func runningDock() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: DockAccessibility.bundleIdentifier).first
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

    /// Reads the icons after `delay`, or later when a read already pending is due later (`DockLayoutSchedule`).
    private func scheduleLayout(after delay: Duration, hidingCounts: Bool) {
        guard dock != nil else { return }
        if hidingCounts {
            isSettling = true
            refreshBadges()
        }
        let due = layoutSchedule.schedule(after: delay, now: .now)
        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            try? await Task.sleep(until: due, clock: .continuous)
            guard !Task.isCancelled else { return }
            await self?.readLayout()
        }
    }

    /// Stores the icons read, unless another read was asked for while this one ran: that one comes later and counts. A
    /// Dock read while hidden or sliding keeps the last layout read while it was out, and counts that stepped aside stay
    /// aside until the next read.
    private func readLayout() async {
        guard let dock else { return }
        let read = layoutSchedule.begin()
        let displays = DisplayDirectory.current().map(\.bounds)
        let fresh = await dock.layout(displays: displays)
        guard self.dock === dock, layoutSchedule.isCurrent(read) else { return }
        if let fresh, !fresh.isOnScreen(displays: displays) {
            return
        }
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
        // Icons that share a bundle ID are told apart by the bundle each process runs from.
        let iconCounts = Dictionary(ids.values.map { ($0, 1) }, uniquingKeysWith: +)
        let shared = Set(iconCounts.filter { $0.value > 1 }.keys)
        var files: [Int: DockWindowMap.FileID] = [:]
        for (index, id) in ids where shared.contains(id) {
            files[index] = items[index].url.flatMap(Self.fileID(of:))
        }
        let wanted = Set(ids.values)
        let processes = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.bundleIdentifier.map(wanted.contains) == true }
            .sorted { ($0.launchDate ?? .distantFuture, $0.processIdentifier) < ($1.launchDate ?? .distantFuture, $1.processIdentifier) }
            .compactMap { app in
                app.bundleIdentifier.map { id in
                    DockWindowMap.Process(
                        pid: app.processIdentifier,
                        bundleID: id,
                        file: shared.contains(id) ? app.bundleURL.flatMap(Self.fileID(of:)) : nil
                    )
                }
            }
        return DockWindowMap.windows(for: items, bundleIDs: ids, files: files, processes: processes, entries: entries)
    }

    /// The bundle at `url` as a file, the same for every path to it; nil when it is gone.
    private static func fileID(of url: URL) -> DockWindowMap.FileID? {
        var info = stat()
        let found = url.withUnsafeFileSystemRepresentation { path in path.map { stat($0, &info) == 0 } ?? false }
        return found ? DockWindowMap.FileID(device: info.st_dev, inode: info.st_ino) : nil
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

    /// Whether the pointer left the icon, the panel and the Dock though the Dock did not say so. The icon counts as the
    /// hover read found it, which a magnified Dock grows past the icons read with the pointer away; the Dock as last read
    /// counts only while it still holds the hovered icon.
    private func pointerMoved() {
        guard panel.isVisible, let hovered = machine.hovered else { return }
        let area = layout.flatMap { $0.holds(hovered) ? $0.area : nil }
        let keeps = DockPreviewLayout.keepsPreview(
            pointer: NSEvent.mouseLocation,
            icon: ScreenLocator.cocoaRect(fromCG: hovered.frame),
            panel: panel.frame,
            dock: area.map { ScreenLocator.cocoaRect(fromCG: $0) }
        )
        guard !keeps else { return }
        apply(machine.handle(.hovered(nil)))
    }
}
