import ApplicationServices

/// Turns AX observer callbacks into `WindowSourceEvent`s. The observers' run-loop sources sit on the main run
/// loop, so callbacks arrive on the main thread; the relay only reads the pid (a local call, no IPC) and yields
/// an event, so no AX request ever runs on the main thread.
final nonisolated class AXNotificationRelay: Sendable {
    /// Registered on each application element.
    static let applicationNotifications = [
        kAXWindowCreatedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXApplicationActivatedNotification,
        kAXApplicationHiddenNotification,
        kAXApplicationShownNotification,
    ]

    /// Registered on each window element.
    static let windowNotifications = [
        kAXUIElementDestroyedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]

    private let sink: @Sendable (WindowSourceEvent) -> Void

    init(sink: @escaping @Sendable (WindowSourceEvent) -> Void) {
        self.sink = sink
    }

    func deliver(pid: Int32, notification: String) {
        if let event = Self.event(for: notification, pid: pid) {
            sink(event)
        }
    }

    static func event(for notification: String, pid: Int32) -> WindowSourceEvent? {
        switch notification {
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            .focusedWindowChanged(pid)
        case kAXApplicationActivatedNotification:
            .appActivated(pid)
        case kAXApplicationHiddenNotification:
            .appHidden(pid)
        case kAXApplicationShownNotification:
            .appUnhidden(pid)
        case kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXWindowMovedNotification,
             kAXWindowResizedNotification, kAXTitleChangedNotification, kAXWindowMiniaturizedNotification,
             kAXWindowDeminiaturizedNotification:
            .windowsChanged(pid)
        default:
            nil
        }
    }
}

/// The C callback every switcher `AXObserver` uses; `refcon` is the relay, unretained (the AX actor owns it).
nonisolated func axObserverCallback(
    _: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return }
    Unmanaged<AXNotificationRelay>.fromOpaque(refcon).takeUnretainedValue().deliver(pid: pid, notification: notification as String)
}
