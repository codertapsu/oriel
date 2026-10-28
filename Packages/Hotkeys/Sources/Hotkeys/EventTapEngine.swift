import AppKit
import CoreGraphics
import OrielCore
import os

/// The switcher's one active event tap (PLAN §7.1.4): session level, inserted at the head, so it sees every
/// key — and modifier releases — before the front app does and can consume them. Needs Accessibility.
///
/// The callback only converts the event and asks `handler` synchronously; it returns in well under a
/// millisecond, because a slow tap is disabled by the system. When that happens anyway, it re-enables itself.
@MainActor
public final class EventTapEngine {
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let keyboard = Options(rawValue: 1 << 0)
        public static let gestures = Options(rawValue: 1 << 1)
        public static let leftMouse = Options(rawValue: 1 << 2)
    }

    /// Decides, per event, whether the front app gets it.
    public var handler: (@MainActor (TapEvent) -> TapDecision)?
    public private(set) var isRunning = false
    public private(set) var timesReenabled = 0

    private let options: Options
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let log = Log.logger("hotkeys")

    /// The CGEventType raw value of `NSEvent.EventType.gesture` (29), which CGEventType does not name.
    static let gestureType: UInt32 = 29

    public init(options: Options = [.keyboard]) {
        self.options = options
    }

    public func start() throws {
        guard !isRunning else { return }
        var mask: CGEventMask = 0
        if options.contains(.keyboard) {
            for type in [CGEventType.keyDown, .keyUp, .flagsChanged] {
                mask |= 1 << CGEventMask(type.rawValue)
            }
        }
        if options.contains(.gestures) {
            mask |= 1 << CGEventMask(Self.gestureType)
        }
        if options.contains(.leftMouse) {
            mask |= 1 << CGEventMask(CGEventType.leftMouseDown.rawValue)
        }
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: me
        )
        else {
            throw HotkeyError.tapUnavailable
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        isRunning = true
    }

    public func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        isRunning = false
    }

    /// Re-enables a tap the system switched off, e.g. after waking. Call it when the app becomes active.
    public func ensureEnabled() {
        guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        timesReenabled += 1
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        let tapEvent: TapEvent
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            timesReenabled += 1
            log.notice("event tap was disabled (\(type.rawValue)); re-enabled")
            return false
        case .keyDown:
            tapEvent = .keyDown(
                keyCode: Self.keyCode(event),
                modifiers: .init(cgFlags: event.flags),
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        case .keyUp:
            tapEvent = .keyUp(keyCode: Self.keyCode(event), modifiers: .init(cgFlags: event.flags))
        case .flagsChanged:
            tapEvent = .flagsChanged(modifiers: .init(cgFlags: event.flags))
        case .leftMouseDown:
            tapEvent = .leftMouseDown(location: event.location)
        default:
            guard type.rawValue == Self.gestureType, let touches = Self.touches(of: event) else { return false }
            tapEvent = .gesture(touches: touches)
        }
        return handler?(tapEvent) == .consume
    }

    private static func keyCode(_ event: CGEvent) -> UInt16 {
        UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
    }

    private static func touches(of event: CGEvent) -> [TouchSample]? {
        guard let nsEvent = NSEvent(cgEvent: event) else { return nil }
        return nsEvent.allTouches().map { touch in
            TouchSample(identity: (touch.identity as? NSObject)?.hash ?? 0, position: touch.normalizedPosition, isResting: touch.isResting)
        }
    }
}

/// The tap's run-loop source is on the main run loop, so the callback runs on the main thread.
private func eventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<EventTapEngine>.fromOpaque(refcon).takeUnretainedValue()
    nonisolated(unsafe) let event = event
    let consume = MainActor.assumeIsolated { engine.handle(type: type, event: event) }
    return consume ? nil : Unmanaged.passUnretained(event)
}
