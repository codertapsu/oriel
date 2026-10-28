import ApplicationServices
import Dispatch
import OrielCore
import os
import PrivateAPIs

/// The AX actor (PLAN §6.4, CLAUDE.md rule 6): every `AXUIElement` call of the switcher runs here, on a
/// dedicated serial queue rather than the cooperative pool, because AX calls are synchronous IPC that block
/// for as long as the target app takes. Every element gets a 0.25 s messaging timeout, so a hung app costs at
/// most that per call, and an app that times out is skipped for the rest of the read.
///
/// AX elements never leave the actor: callers get `AXWindowRecord` values and refer to windows by id.
actor AXClient {
    static let messagingTimeout: Float = 0.25
    /// The remote-token search covers element ids 0..<1000 and gives up after 100 ms per app (PLAN §7.1.1
    /// item 2). On macOS 27.0.1 window elements sat at ids 42–53 in most apps, but beyond 1000 in one
    /// long-running Chromium browser; those windows appear once their Space has been visited.
    static let remoteElementIDLimit: UInt64 = 1000
    static let remoteTimeBudget: Duration = .milliseconds(100)

    private struct ObservedApp {
        let element: AXUIElement
        let observer: AXObserver?
        var observedWindows: Set<UInt32> = []
    }

    private let queue = DispatchSerialQueue(label: "com.codertapsu.oriel.switcher.ax", qos: .userInitiated)
    private let apis: PrivateAPIs
    /// Nil for one-shot reads (the CLI before the module is active, tests): no observers are installed.
    private let relay: AXNotificationRelay?
    private let log = Log.logger("switcher")

    private var applications: [Int32: ObservedApp] = [:]
    /// Window id → element, for windows on any Space; the source of actions and other-Space titles.
    private var elements: [UInt32: AXUIElement] = [:]
    private var owners: [UInt32: Int32] = [:]
    /// Window ids a remote-token search already looked for, so each is searched for once.
    private var remoteAttempted: Set<UInt32> = []

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    init(apis: PrivateAPIs, relay: AXNotificationRelay?) {
        self.apis = apis
        self.relay = relay
    }

    // MARK: Reading

    /// The windows `kAXWindowsAttribute` lists: the visible Spaces' windows and minimized ones.
    func windows(of pid: Int32) -> AXWindowsResult {
        guard let app = application(pid) else { return .refused }
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(app.element, kAXWindowsAttribute as CFString, &value) {
        case .success:
            break
        case .noValue, .attributeUnsupported:
            return .windows([])
        default:
            // .cannotComplete (launching or hung), .apiDisabled, .notImplemented: retried on activation.
            return .refused
        }
        guard let windows = value as? [AXUIElement] else { return .windows([]) }
        var records: [AXWindowRecord] = []
        for window in windows {
            AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)
            guard var record = AXAttributeReader.record(of: window) else { continue }
            record.windowID = apis.windowID(of: window)
            record.isListed = true
            if let id = record.windowID {
                remember(window, id: id, pid: pid)
            }
            records.append(record)
        }
        return .windows(records)
    }

    /// Windows the app does not list, from elements cached while they were visible, else from remote tokens.
    func otherSpaceWindows(of pid: Int32, ids: Set<UInt32>) -> [AXWindowRecord] {
        var records: [AXWindowRecord] = []
        var missing = Set<UInt32>()
        for id in ids {
            if let element = elements[id], owners[id] == pid {
                if let record = unlistedRecord(of: element, id: id) {
                    records.append(record)
                }
            } else if !remoteAttempted.contains(id) {
                missing.insert(id)
            }
        }
        guard !missing.isEmpty, apis.canReachOtherSpaces else { return records }
        remoteAttempted.formUnion(missing)
        for (id, element) in remoteElements(pid: pid, wanted: missing) {
            remember(element, id: id, pid: pid)
            if let record = unlistedRecord(of: element, id: id) {
                records.append(record)
            }
        }
        return records
    }

    func focusedWindowID(of pid: Int32) -> UInt32? {
        guard let app = application(pid), let window = AXAttributeReader.element(kAXFocusedWindowAttribute, of: app.element) else {
            return nil
        }
        AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)
        guard let id = apis.windowID(of: window) else { return nil }
        remember(window, id: id, pid: pid)
        return id
    }

    // MARK: Actions

    /// `AXRaise` and `kAXMainAttribute = true` (PLAN §7.1.3).
    func raise(windowID: UInt32) -> Bool {
        guard let element = elements[windowID] else { return false }
        let raised = AXAttributeReader.perform(kAXRaiseAction, on: element)
        let main = AXAttributeReader.set(kAXMainAttribute, to: true, on: element)
        return raised || main
    }

    func setMinimized(_ minimized: Bool, windowID: UInt32) -> Bool {
        guard let element = elements[windowID] else { return false }
        return AXAttributeReader.set(kAXMinimizedAttribute, to: minimized, on: element)
    }

    /// Presses the close button, like a click on it.
    func close(windowID: UInt32) -> Bool {
        guard let element = elements[windowID],
              let button = AXAttributeReader.element(kAXCloseButtonAttribute, of: element)
        else { return false }
        AXUIElementSetMessagingTimeout(button, Self.messagingTimeout)
        return AXAttributeReader.perform(kAXPressAction, on: button)
    }

    /// Flips `AXFullScreen`; apps that refuse the attribute get a press of their full-screen button.
    func toggleFullScreen(windowID: UInt32) -> Bool {
        guard let element = elements[windowID] else { return false }
        let isFullScreen = AXAttributeReader.bool(AXAttributeReader.fullScreenAttribute, of: element) ?? false
        if AXAttributeReader.set(AXAttributeReader.fullScreenAttribute, to: !isFullScreen, on: element) {
            return true
        }
        guard let button = AXAttributeReader.element(kAXFullScreenButtonAttribute, of: element) else { return false }
        AXUIElementSetMessagingTimeout(button, Self.messagingTimeout)
        return AXAttributeReader.perform(kAXPressAction, on: button)
    }

    // MARK: Housekeeping

    func forget(pid: Int32) {
        if let app = applications.removeValue(forKey: pid) {
            remove(app)
        }
        for (id, owner) in owners where owner == pid {
            elements[id] = nil
            owners[id] = nil
            remoteAttempted.remove(id)
        }
    }

    /// Drops elements of windows the server no longer lists.
    func prune(keeping alive: Set<UInt32>) {
        for id in elements.keys where !alive.contains(id) {
            elements[id] = nil
            owners[id] = nil
        }
        remoteAttempted.formIntersection(alive)
        for pid in applications.keys {
            applications[pid]?.observedWindows.formIntersection(alive)
        }
    }

    /// Removes every observer, so no callback can arrive after the module is deactivated.
    func removeAllObservers() {
        for app in applications.values {
            remove(app)
        }
        applications.removeAll()
        elements.removeAll()
        owners.removeAll()
        remoteAttempted.removeAll()
    }

    // MARK: Private

    /// The app element, with an observer when the client observes. Nil when the app refuses (still launching).
    private func application(_ pid: Int32) -> ObservedApp? {
        if let app = applications[pid] {
            return app
        }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        var observer: AXObserver?
        if let relay {
            guard let created = makeObserver(pid: pid, element: element, relay: relay) else { return nil }
            observer = created
        }
        let app = ObservedApp(element: element, observer: observer)
        applications[pid] = app
        return app
    }

    private func makeObserver(pid: Int32, element: AXUIElement, relay: AXNotificationRelay) -> AXObserver? {
        var created: AXObserver?
        guard AXObserverCreate(pid, axObserverCallback, &created) == .success, let observer = created else { return nil }
        let refcon = Unmanaged.passUnretained(relay).toOpaque()
        // Registers each notification in turn and stops at the first .cannotComplete: an app that is still
        // launching does not answer yet and is retried when it activates.
        let refused = AXNotificationRelay.applicationNotifications.contains { notification in
            AXObserverAddNotification(observer, element, notification as CFString, refcon) == .cannotComplete
        }
        guard !refused else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        return observer
    }

    private func remove(_ app: ObservedApp) {
        guard let observer = app.observer else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Caches the element and, the first time, registers the per-window notifications.
    private func remember(_ window: AXUIElement, id: UInt32, pid: Int32) {
        elements[id] = window
        owners[id] = pid
        guard let relay, var app = applications[pid], let observer = app.observer, !app.observedWindows.contains(id) else { return }
        let refcon = Unmanaged.passUnretained(relay).toOpaque()
        for notification in AXNotificationRelay.windowNotifications {
            AXObserverAddNotification(observer, window, notification as CFString, refcon)
        }
        app.observedWindows.insert(id)
        applications[pid] = app
    }

    private func unlistedRecord(of element: AXUIElement, id: UInt32) -> AXWindowRecord? {
        guard var record = AXAttributeReader.record(of: element) else { return nil }
        record.windowID = id
        record.isListed = false
        return record
    }

    /// Builds elements from remote tokens until every wanted window is found, the id range ends, the time
    /// budget runs out or the app stops answering.
    private func remoteElements(pid: Int32, wanted: Set<UInt32>) -> [UInt32: AXUIElement] {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.remoteTimeBudget)
        var remaining = wanted
        var found: [UInt32: AXUIElement] = [:]
        for elementID in 0 ..< Self.remoteElementIDLimit {
            guard !remaining.isEmpty, clock.now < deadline else { break }
            let token = PrivateAPIs.remoteToken(pid: pid, elementID: elementID)
            guard let element = apis.element(fromRemoteToken: token) else { continue }
            AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
            var role: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            if error == .cannotComplete {
                break
            }
            guard error == .success, role as? String == kAXWindowRole, let id = apis.windowID(of: element),
                  remaining.remove(id) != nil
            else { continue }
            found[id] = element
        }
        if !remaining.isEmpty {
            log.debug("remote tokens: \(remaining.count) of \(wanted.count) windows of pid \(pid) not reached")
        }
        return found
    }
}
