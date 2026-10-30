import ApplicationServices

/// Turns the Dock's AX observer callbacks into `DockEvent`s. As with `AXNotificationRelay`, the observer's run-loop source
/// sits on the main run loop and the relay makes no AX request: it maps the notification's name and yields an event.
final nonisolated class DockNotificationRelay: Sendable {
    /// Registered on the Dock's list. On macOS 27.0.1 the Dock supports these and not moved, resized or layout changed.
    static let notifications = [
        kAXSelectedChildrenChangedNotification,
        kAXCreatedNotification,
        kAXUIElementDestroyedNotification,
    ]

    private let sink: @Sendable (DockEvent) -> Void

    init(sink: @escaping @Sendable (DockEvent) -> Void) {
        self.sink = sink
    }

    func deliver(_ notification: String) {
        if let event = Self.event(for: notification) {
            sink(event)
        }
    }

    static func event(for notification: String) -> DockEvent? {
        switch notification {
        case kAXSelectedChildrenChangedNotification: .hoverChanged
        case kAXCreatedNotification, kAXUIElementDestroyedNotification: .itemsChanged
        default: nil
        }
    }
}

/// The C callback of the Dock's `AXObserver`; `refcon` is the relay, unretained (the Dock's AX actor owns it).
nonisolated func dockObserverCallback(
    _: AXObserver,
    _: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    Unmanaged<DockNotificationRelay>.fromOpaque(refcon).takeUnretainedValue().deliver(notification as String)
}
