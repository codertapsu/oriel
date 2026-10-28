import Carbon.HIToolbox
import OrielCore

/// Global shortcuts for capture, translate and record (PLAN §7.1.4), through Carbon's RegisterEventHotKey.
/// It needs no permission and cannot see or swallow other keys; the switcher uses `EventTapEngine` instead.
@MainActor
public final class CarbonHotkeyEngine {
    private struct Registration {
        let number: UInt32
        let ref: EventHotKeyRef
        let combo: KeyCombo
    }

    private var registrations: [String: Registration] = [:]
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var nextNumber: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    public init() {}

    /// Registers `combo` under `name`, replacing whatever `name` had before.
    public func register(_ combo: KeyCombo, name: String, handler: @escaping @MainActor () -> Void) throws {
        unregister(name)
        try installDispatcher()
        let number = nextNumber
        nextNumber += 1
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4F52_494C), id: number) // 'ORIL'
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbonFlags, id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { throw HotkeyError.registrationFailed(combo, status) }
        registrations[name] = Registration(number: number, ref: ref, combo: combo)
        handlers[number] = handler
    }

    public func unregister(_ name: String) {
        guard let registration = registrations.removeValue(forKey: name) else { return }
        UnregisterEventHotKey(registration.ref)
        handlers[registration.number] = nil
    }

    public func unregisterAll() {
        for name in Array(registrations.keys) {
            unregister(name)
        }
    }

    /// What is registered, by name.
    public var registered: [String: KeyCombo] {
        registrations.mapValues(\.combo)
    }

    fileprivate func fire(_ number: UInt32) {
        handlers[number]?()
    }

    private func installDispatcher() throws {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), carbonHotkeyCallback, 1, &spec, me, &eventHandler)
        guard status == noErr else { throw HotkeyError.registrationFailed(KeyCombo(keyCode: 0, modifiers: []), status) }
    }
}

/// Carbon delivers hot-key events on the main thread, through the main event loop.
private func carbonHotkeyCallback(_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &id
    )
    guard status == noErr else { return status }
    let engine = Unmanaged<CarbonHotkeyEngine>.fromOpaque(userData).takeUnretainedValue()
    let number = id.id
    MainActor.assumeIsolated { engine.fire(number) }
    return noErr
}
