import AppKit
import SharedUI

/// Notices clipboard changes without polling (CLAUDE.md rule 3). macOS posts nothing when the pasteboard changes, so
/// its change count is compared after what comes just before a copy: a click or a key press anywhere, another app
/// coming to the front, waking up, and Clipboard History opening. The event monitors only time a check; they never
/// look at which key was pressed, and they watch keys only with Accessibility, which macOS requires for that.
final class PasteboardWatcher {
    /// Called with the new change count when another app has changed the pasteboard.
    var onChange: ((Int) -> Void)?

    private let changeCount: () -> Int
    private let ownWriteChangeCount: () -> Int?
    private let watchesKeys: () -> Bool
    private let workspaceCenter: NotificationCenter
    private let localCenter: NotificationCenter
    /// After an event, one check soon and one a little later, for apps that write the pasteboard slowly.
    private let delays: [Duration]
    private var lastChangeCount = 0
    private var monitors: [Any] = []
    private var monitorsWatchKeys = false
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    private var pendingCheck: Task<Void, Never>?
    private(set) var isRunning = false

    init(
        changeCount: @escaping () -> Int = { NSPasteboard.general.changeCount },
        ownWriteChangeCount: @escaping () -> Int? = { Pasteboard.lastWriteChangeCount },
        watchesKeys: @escaping () -> Bool,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        localCenter: NotificationCenter = .default,
        delays: [Duration] = [.milliseconds(150), .milliseconds(850)]
    ) {
        self.changeCount = changeCount
        self.ownWriteChangeCount = ownWriteChangeCount
        self.watchesKeys = watchesKeys
        self.workspaceCenter = workspaceCenter
        self.localCenter = localCenter
        self.delays = delays
    }

    /// Starts from the pasteboard as it is: what was copied before is not reported.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastChangeCount = changeCount()
        installMonitors()
        let soon: @MainActor (PasteboardWatcher) -> Void = { $0.checkNow() }
        observe(NSWorkspace.didActivateApplicationNotification, on: workspaceCenter) { watcher in
            watcher.refreshMonitors()
            watcher.checkNow()
            watcher.scheduleCheck()
        }
        observe(NSWorkspace.didWakeNotification, on: workspaceCenter, perform: soon)
        observe(NSWorkspace.sessionDidBecomeActiveNotification, on: workspaceCenter, perform: soon)
        observe(NSApplication.didBecomeActiveNotification, on: localCenter, perform: soon)
        observe(NSApplication.didResignActiveNotification, on: localCenter, perform: soon)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        removeMonitors()
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers = []
        pendingCheck?.cancel()
        pendingCheck = nil
    }

    /// Compares the change count now, and reports a change another app made.
    func checkNow() {
        guard isRunning else { return }
        let count = changeCount()
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        // Oriel's own copies are announced through `Pasteboard.writes()` with what was written.
        guard count != ownWriteChangeCount() else { return }
        onChange?(count)
    }

    /// Checks in a moment, because the app that copies may write a little after the key press or click; another event
    /// meanwhile starts the wait again. One-shot waits, not a timer.
    func scheduleCheck() {
        guard isRunning else { return }
        pendingCheck?.cancel()
        let delays = delays
        pendingCheck = Task { [weak self] in
            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.checkNow()
            }
        }
    }

    /// Re-installs the monitors when Accessibility has been granted or taken away since they were installed.
    func refreshMonitors() {
        guard isRunning, watchesKeys() != monitorsWatchKeys else { return }
        removeMonitors()
        installMonitors()
    }

    private func installMonitors() {
        monitorsWatchKeys = watchesKeys()
        var global: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]
        if monitorsWatchKeys {
            global.insert(.keyDown)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: global, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }) {
            monitors.append(monitor)
        }
        // Copies made in Oriel's own windows (a Settings field, say) do not reach the global monitor.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseUp, .rightMouseUp], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.scheduleCheck() }
            return event
        }) {
            monitors.append(monitor)
        }
    }

    private func removeMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        perform: @escaping @MainActor (PasteboardWatcher) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                perform(self)
            }
        }
        observers.append((center, token))
    }
}
