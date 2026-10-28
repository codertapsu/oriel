import AppKit
import Hotkeys
import OrielCore
import os

/// Everything that runs while the switcher is active: the observing window source and the store, the
/// controller and its one event tap, thumbnails and the memory-pressure source. `stop` tears all of it down
/// and leaves no observers, taps or timers (PLAN §6.3).
final class SwitcherRuntime {
    let source: any WindowSource
    let store: WindowStore
    let controller: SwitcherController
    private let thumbnails: ThumbnailService
    private let memoryPressure = MemoryPressureMonitor()
    private let log = Log.logger("switcher")

    private var tap: EventTapEngine?
    private var tapUsesGestures = false
    private var storeTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var activationObserver: (any NSObjectProtocol)?

    init(source: any WindowSource, configuration: SwitcherConfiguration, capturer: any WindowCapturing = ScreenCaptureKitCapturer()) {
        self.source = source
        store = WindowStore(source: source, rules: EligibilityRules(exceptions: configuration.exceptions))
        thumbnails = ThumbnailService(capturer: capturer)
        controller = SwitcherController(store: store, source: source, thumbnails: thumbnails, configuration: configuration)
    }

    func start(configuration: SwitcherConfiguration) {
        let store = store
        storeTask = Task { await store.run() }
        snapshotTask = Task { [weak self] in
            for await entries in await store.snapshots() {
                self?.controller.update(entries: entries)
            }
        }
        startTap(gestures: configuration.gesturesEnabled)
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
        if tapUsesGestures != configuration.gesturesEnabled {
            tap?.stop()
            tap = nil
            startTap(gestures: configuration.gesturesEnabled)
        }
        await store.setRules(EligibilityRules(exceptions: configuration.exceptions))
    }

    func stop() async {
        tap?.stop()
        tap = nil
        controller.stop()
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
        let keep = controller.isOpen ? controller.visibleWindowIDs : []
        let thumbnails = thumbnails
        Task { await thumbnails.purge(keeping: keep) }
        log.notice("memory pressure: purged thumbnails")
    }
}
