import ApplicationServices
import CoreGraphics
import Dispatch
import Foundation
import OrielCore
import os

/// The Dock's AX actor (PLAN §7.1.12, CLAUDE.md rule 6): every request to the Dock runs here, on a serial queue of its own
/// so that a slow app the switcher is reading never delays a hover, with the switcher's 0.25 s messaging timeout. It
/// observes the Dock's list for hover and for icons added or removed, and reads each icon in one round trip
/// (`AXUIElementCopyMultipleAttributeValues`). The Dock is another process, so no request reaches Oriel's own.
///
/// One instance per run of the Dock features: `stop` finishes `events`.
actor DockAccessibility {
    static let bundleIdentifier = "com.apple.dock"

    /// An icon's attributes, in the order `item(from:)` reads them.
    private static let itemAttributes = [
        kAXSubroleAttribute, kAXTitleAttribute, kAXURLAttribute, kAXPositionAttribute, kAXSizeAttribute,
        kAXIsApplicationRunningAttribute,
    ]

    let events: AsyncStream<DockEvent>

    private let continuation: AsyncStream<DockEvent>.Continuation
    private let relay: DockNotificationRelay
    private let queue = DispatchSerialQueue(label: "com.codertapsu.oriel.switcher.dock", qos: .userInitiated)
    private let log = Log.logger("switcher")

    /// The Dock process observed, and its list of icons.
    private(set) var pid: pid_t?
    private var list: AXUIElement?
    private var observer: AXObserver?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: DockEvent.self)
        events = stream
        self.continuation = continuation
        relay = DockNotificationRelay { continuation.yield($0) }
    }

    /// Observes the list of the Dock running as `pid`. False when it does not answer (it is starting, or Accessibility is
    /// off); the controller tries again at the next change.
    @discardableResult
    func start(pid: pid_t) -> Bool {
        removeObserver()
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, AXClient.messagingTimeout)
        guard let list = AXAttributeReader.elements(kAXChildrenAttribute, of: app)?
            .first(where: { AXAttributeReader.string(kAXRoleAttribute, of: $0) == kAXListRole })
        else {
            self.pid = nil
            list = nil
            log.notice("the Dock did not answer; its previews and counts wait for the next change")
            return false
        }
        AXUIElementSetMessagingTimeout(list, AXClient.messagingTimeout)
        self.pid = pid
        self.list = list
        var created: AXObserver?
        guard AXObserverCreate(pid, dockObserverCallback, &created) == .success, let observer = created else { return true }
        let refcon = Unmanaged.passUnretained(relay).toOpaque()
        for notification in DockNotificationRelay.notifications {
            AXObserverAddNotification(observer, list, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        self.observer = observer
        return true
    }

    /// Removes the observer and finishes `events`, so no callback arrives after the features stop.
    func stop() {
        removeObserver()
        pid = nil
        list = nil
        continuation.finish()
    }

    /// Every icon in order, the list's frame and the Dock's edge. Nil when the Dock does not answer.
    func layout(displays: [CGRect]) -> DockLayout? {
        guard let list, let frame = frame(of: list) else { return nil }
        let items = (AXAttributeReader.elements(kAXChildrenAttribute, of: list) ?? []).compactMap(item(from:))
        let isVertical = AXAttributeReader.string(kAXOrientationAttribute, of: list) == kAXVerticalOrientationValue
        return DockLayout(items: items, frame: frame, edge: DockLayout.edge(isVertical: isVertical, frame: frame, displays: displays))
    }

    /// The icon under the pointer, which the Dock reports as its list's selected child; nil off the Dock.
    func hoveredItem() -> DockItem? {
        guard let list, let selected = AXAttributeReader.elements(kAXSelectedChildrenAttribute, of: list)?.first else { return nil }
        return item(from: selected)
    }

    private func item(from element: AXUIElement) -> DockItem? {
        AXUIElementSetMessagingTimeout(element, AXClient.messagingTimeout)
        var values: CFArray?
        let names = Self.itemAttributes as CFArray
        guard AXUIElementCopyMultipleAttributeValues(element, names, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
              let array = values as [AnyObject]?, array.count == Self.itemAttributes.count
        else { return nil }
        return DockItem.make(
            subrole: array[0] as? String,
            title: array[1] as? String,
            url: array[2] as? URL,
            position: AXAttributeReader.point(array[3]),
            size: AXAttributeReader.size(array[4]),
            isRunning: array[5] as? Bool
        )
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = AXAttributeReader.value(kAXPositionAttribute, of: element).flatMap({ AXAttributeReader.point($0) }),
              let size = AXAttributeReader.value(kAXSizeAttribute, of: element).flatMap({ AXAttributeReader.size($0) })
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func removeObserver() {
        guard let observer else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        self.observer = nil
    }
}
