import AppKit
import Hotkeys
import OrielCore
import os

/// Everything that runs while the switcher or the Dock's previews and counts are on: the observing window source and the
/// store, the controller and, while the switcher is on, its one event tap, the Dock controller (PLAN §7.1.12),
/// thumbnails and the memory-pressure source. `stop` tears all of it down and leaves no observers, taps or timers
/// (PLAN §6.3).
final class SwitcherRuntime {
    let source: any WindowSource
    let store: WindowStore
    let controller: SwitcherController
    let dock: DockController
    private let thumbnails: ThumbnailService
    private let memoryPressure = MemoryPressureMonitor()
    private let log = Log.logger("switcher")

    private var tap: EventTapEngine?
    private var tapUsesGestures = false
    /// Whether the switcher itself is on, rather than only the Dock's features.
    private(set) var isSwitcherOn = false
    private var storeTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var activationObserver: (any NSObjectProtocol)?

    init(source: any WindowSource, configuration: SwitcherConfiguration, capturer: any WindowCapturing = ScreenCaptureKitCapturer()) {
        self.source = source
        store = WindowStore(source: source, rules: EligibilityRules(exceptions: configuration.exceptions))
        thumbnails = ThumbnailService(capturer: capturer)
        controller = SwitcherController(store: store, source: source, thumbnails: thumbnails, configuration: configuration)
        dock = DockController(store: store, source: source, thumbnails: thumbnails)
        controller.onOpen = { [weak dock] in dock?.hidePreview() }
    }

    func start(configuration: SwitcherConfiguration) {
        let store = store
        storeTask = Task { await store.run() }
        snapshotTask = Task { [weak self] in
            for await entries in await store.snapshots() {
                self?.controller.update(entries: entries)
                self?.dock.update(entries: entries)
            }
        }
        applyTap(configuration)
        applyDock(configuration)
        memoryPressure.start { [weak self] in self?.purgeThumbnails() }
        // The system disables a tap that was slow (or after sleep); coming back to the app re-enables it.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tap?.ensureEnabled() }
        }
    }

    func apply(_ configuration: SwitcherConfiguration) async {
        controller.update(configuration: configuration)
        applyTap(configuration)
        applyDock(configuration)
        await store.setRules(EligibilityRules(exceptions: configuration.exceptions))
    }

    func stop() async {
        tap?.stop()
        tap = nil
        isSwitcherOn = false
        controller.stop()
        dock.stop()
        memoryPressure.stop()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = nil
        storeTask?.cancel()
        snapshotTask?.cancel()
        storeTask = nil
        snapshotTask = nil
        await store.shutdown()
        await source.stop()
        await thumbnails.removeAll()
    }

    /// The tap runs while the switcher is on, with gestures when they are; the Dock's features need none.
    private func applyTap(_ configuration: SwitcherConfiguration) {
        isSwitcherOn = configuration.isEnabled
        guard configuration.isEnabled else {
            tap?.stop()
            tap = nil
            return
        }
        guard tap == nil || tapUsesGestures != configuration.gesturesEnabled else { return }
        tap?.stop()
        tap = nil
        startTap(gestures: configuration.gesturesEnabled)
    }

    private func applyDock(_ configuration: SwitcherConfiguration) {
        dock.apply(
            showsPreviews: configuration.showsDockPreviews,
            showsCounts: configuration.showsDockWindowCounts,
            tileWidth: configuration.thumbnailWidth
        )
    }

    private func startTap(gestures: Bool) {
        let engine = EventTapEngine(options: gestures ? [.keyboard, .gestures] : [.keyboard])
        engine.handler = { [weak self] event in
            self?.controller.handle(event) ?? .pass
        }
        do {
            try engine.start()
            tap = engine
            tapUsesGestures = gestures
        } catch {
            log.error("the switcher's event tap could not start: \(String(describing: error), privacy: .public)")
        }
    }

    private func purgeThumbnails() {
        let keep = (controller.isOpen ? controller.visibleWindowIDs : []).union(dock.visibleWindowIDs)
        let thumbnails = thumbnails
        Task { await thumbnails.purge(keeping: keep) }
        log.notice("memory pressure: purged thumbnails")
    }
}
