import AppKit
import Hotkeys

/// A listen-only event tap on the session's gesture events, for recording fixtures: it keeps every frame as the
/// switcher's event tap reads it (`EventTapEngine`) and passes every event on.
@MainActor
final class GestureTap {
    private(set) var frames: [[TouchSample]] = []
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Listens on the main run loop; nil when macOS refuses the tap (the terminal has no Accessibility).
    static func start() -> GestureTap? {
        let recorder = GestureTap()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1) << 29,
            callback: gestureTapCallback,
            userInfo: Unmanaged.passUnretained(recorder).toOpaque()
        ) else { return nil }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        recorder.tap = tap
        recorder.source = source
        return recorder
    }

    func clear() {
        frames.removeAll()
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CFMachPortInvalidate(tap)
        }
        tap = nil
        source = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        guard type.rawValue == 29, let touches = NSEvent(cgEvent: event)?.allTouches() else { return }
        frames.append(touches.map { touch in
            TouchSample(identity: (touch.identity as? NSObject)?.hash ?? 0, position: touch.normalizedPosition, isResting: touch.isResting)
        })
    }
}

/// The tap's source is on the main run loop, so the callback runs on the main thread.
private func gestureTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        let recorder = Unmanaged<GestureTap>.fromOpaque(refcon).takeUnretainedValue()
        nonisolated(unsafe) let event = event
        MainActor.assumeIsolated { recorder.handle(type: type, event: event) }
    }
    return Unmanaged.passUnretained(event)
}
