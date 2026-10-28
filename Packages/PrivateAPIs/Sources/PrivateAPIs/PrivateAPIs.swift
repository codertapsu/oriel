import ApplicationServices
import CoreGraphics
import Foundation

/// Typed, optional access to the private SkyLight and HIServices symbols the window switcher uses
/// (PLAN §6.2, §7.1.2). Nothing is linked directly: a symbol a macOS update removes turns its flag off, and
/// the caller takes its public fallback.
public final class PrivateAPIs: Sendable {
    public static let shared = PrivateAPIs(resolver: .system)

    /// Which symbols resolved, for Settings → Diagnostics and `oriel debug capabilities`.
    public let presence: [PrivateSymbol: Bool]

    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias CreateWithRemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias GetActiveSpaceFn = @convention(c) (Int32) -> UInt64
    private typealias CopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopySpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias SetFrontProcessFn = @convention(c) (UnsafeMutableRawPointer, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecordFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt8>) -> CGError
    private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutableRawPointer) -> OSStatus
    private typealias GetSymbolicHotKeyValueFn = @convention(c) (
        Int32, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer
    ) -> CGError
    private typealias SetSymbolicHotKeyEnabledFn = @convention(c) (Int32, Bool) -> CGError
    private typealias IsSymbolicHotKeyEnabledFn = @convention(c) (Int32) -> Bool

    private let getWindow: GetWindowFn?
    private let createWithRemoteToken: CreateWithRemoteTokenFn?
    private let mainConnection: MainConnectionFn?
    private let getActiveSpace: GetActiveSpaceFn?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn?
    private let copySpacesForWindows: CopySpacesForWindowsFn?
    private let setFrontProcess: SetFrontProcessFn?
    private let postEventRecord: PostEventRecordFn?
    private let getProcessForPID: GetProcessForPIDFn?
    private let getSymbolicHotKeyValue: GetSymbolicHotKeyValueFn?
    private let setSymbolicHotKeyEnabled: SetSymbolicHotKeyEnabledFn?
    private let isSymbolicHotKeyEnabled: IsSymbolicHotKeyEnabledFn?

    public init(resolver: SymbolResolver) {
        func load<T>(_ symbol: PrivateSymbol, as _: T.Type) -> T? {
            resolver.lookup(symbol.rawValue).map { unsafeBitCast($0, to: T.self) }
        }
        getWindow = load(.axUIElementGetWindow, as: GetWindowFn.self)
        createWithRemoteToken = load(.axUIElementCreateWithRemoteToken, as: CreateWithRemoteTokenFn.self)
        mainConnection = load(.slsMainConnectionID, as: MainConnectionFn.self)
        getActiveSpace = load(.slsGetActiveSpace, as: GetActiveSpaceFn.self)
        copyManagedDisplaySpaces = load(.slsCopyManagedDisplaySpaces, as: CopyManagedDisplaySpacesFn.self)
        copySpacesForWindows = load(.slsCopySpacesForWindows, as: CopySpacesForWindowsFn.self)
        setFrontProcess = load(.slpsSetFrontProcessWithOptions, as: SetFrontProcessFn.self)
        postEventRecord = load(.slpsPostEventRecordTo, as: PostEventRecordFn.self)
        getProcessForPID = load(.getProcessForPID, as: GetProcessForPIDFn.self)
        getSymbolicHotKeyValue = load(.cgsGetSymbolicHotKeyValue, as: GetSymbolicHotKeyValueFn.self)
        setSymbolicHotKeyEnabled = load(.cgsSetSymbolicHotKeyEnabled, as: SetSymbolicHotKeyEnabledFn.self)
        isSymbolicHotKeyEnabled = load(.cgsIsSymbolicHotKeyEnabled, as: IsSymbolicHotKeyEnabledFn.self)
        var presence: [PrivateSymbol: Bool] = [:]
        for symbol in PrivateSymbol.allCases {
            presence[symbol] = resolver.lookup(symbol.rawValue) != nil
        }
        self.presence = presence
    }

    /// `presence` keyed by symbol name, for JSON.
    public var presenceByName: [String: Bool] {
        Dictionary(uniqueKeysWithValues: presence.map { ($0.key.rawValue, $0.value) })
    }

    // MARK: Accessibility

    public var canMapElementsToWindows: Bool {
        getWindow != nil
    }

    public var canReachOtherSpaces: Bool {
        createWithRemoteToken != nil
    }

    /// The `CGWindowID` behind an AX window element.
    public func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var windowID: CGWindowID = 0
        return getWindow(element, &windowID) == .success && windowID != 0 ? windowID : nil
    }

    /// An AX element for a window AX does not list (one on another Space), from its remote token.
    public func element(fromRemoteToken token: Data) -> AXUIElement? {
        guard let createWithRemoteToken else { return nil }
        return createWithRemoteToken(token as CFData)?.takeRetainedValue()
    }

    /// The 20-byte token for element `elementID` of process `pid`: the pid, four zero bytes, the "coco"
    /// marker, and the element id, all little-endian.
    public static func remoteToken(pid: pid_t, elementID: UInt64) -> Data {
        var data = Data(count: 20)
        data.withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: pid.littleEndian, toByteOffset: 0, as: Int32.self)
            bytes.storeBytes(of: UInt32(0), toByteOffset: 4, as: UInt32.self)
            bytes.storeBytes(of: UInt32(0x636F_636F).littleEndian, toByteOffset: 8, as: UInt32.self)
            bytes.storeBytes(of: elementID.littleEndian, toByteOffset: 12, as: UInt64.self)
        }
        return data
    }

    // MARK: Spaces

    public var canReadSpaces: Bool {
        mainConnection != nil && copyManagedDisplaySpaces != nil
    }

    public func activeSpaceID() -> UInt64? {
        guard let mainConnection, let getActiveSpace else { return nil }
        return getActiveSpace(mainConnection())
    }

    public func managedDisplaySpaces() -> [DisplaySpaces]? {
        guard let mainConnection, let copyManagedDisplaySpaces,
              let array = copyManagedDisplaySpaces(mainConnection())?.takeRetainedValue() as? [Any]
        else {
            return nil
        }
        return DisplaySpaces.parse(array)
    }

    /// Every Space the window is on (more than one for "assign to all desktops").
    public func spaceIDs(forWindow windowID: CGWindowID) -> [UInt64]? {
        guard let mainConnection, let copySpacesForWindows else { return nil }
        let windows = [NSNumber(value: windowID)] as CFArray
        // 0x7: current, other and full-screen Spaces.
        guard let array = copySpacesForWindows(mainConnection(), 0x7, windows)?.takeRetainedValue() as? [NSNumber] else {
            return nil
        }
        return array.map(\.uint64Value)
    }

    // MARK: Focus

    public var canFocusWindows: Bool {
        setFrontProcess != nil && postEventRecord != nil && getProcessForPID != nil
    }

    /// Brings exactly one window to the front and makes it key, switching Space if needed (PLAN §7.1.3):
    /// `_SLPSSetFrontProcessWithOptions` in user-generated mode, then two event records that make the window
    /// key. Returns false when a symbol is missing or a call fails, so the caller can fall back to AX raise.
    public func bringToFront(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let setFrontProcess, let postEventRecord, let getProcessForPID else { return false }
        // ProcessSerialNumber is two UInt32s.
        var psn = (UInt32(0), UInt32(0))
        let found = withUnsafeMutablePointer(to: &psn) { getProcessForPID(pid, UnsafeMutableRawPointer($0)) == noErr }
        guard found else { return false }
        let userGenerated: UInt32 = 0x200
        let fronted = withUnsafeMutablePointer(to: &psn) {
            setFrontProcess(UnsafeMutableRawPointer($0), windowID, userGenerated) == .success
        }
        guard fronted else { return false }
        let record = UnsafeMutablePointer<UInt8>.allocate(capacity: 0xF8)
        defer { record.deallocate() }
        record.initialize(repeating: 0, count: 0xF8)
        record[0x04] = 0xF8
        record[0x3A] = 0x10
        withUnsafeBytes(of: windowID.littleEndian) { bytes in
            for (offset, byte) in bytes.enumerated() {
                record[0x3C + offset] = byte
            }
        }
        for offset in 0x20 ..< 0x30 {
            record[offset] = 0xFF
        }
        var ok = true
        for phase: UInt8 in [0x01, 0x02] {
            record[0x08] = phase
            let posted = withUnsafeMutablePointer(to: &psn) { postEventRecord(UnsafeMutableRawPointer($0), record) }
            ok = ok && posted == .success
        }
        return ok
    }

    // MARK: Symbolic hot keys

    public var canControlSymbolicHotKeys: Bool {
        getSymbolicHotKeyValue != nil && setSymbolicHotKeyEnabled != nil
    }

    /// Every symbolic hot key with an id below `limit` that is bound to a key.
    public func symbolicHotKeys(limit: Int32 = 256) -> [SymbolicHotKey] {
        guard let getSymbolicHotKeyValue else { return [] }
        var keys: [SymbolicHotKey] = []
        for id in 0 ..< limit {
            // Wider than the documented unichar / modifier types, and zeroed, so a wrong guess about their
            // width can only lose high bits, never write past the buffer.
            var equivalent = UInt64(0)
            var keyCode = UInt64(0)
            var modifiers = UInt64(0)
            let status = withUnsafeMutablePointer(to: &equivalent) { eq in
                withUnsafeMutablePointer(to: &keyCode) { kc in
                    withUnsafeMutablePointer(to: &modifiers) { md in
                        getSymbolicHotKeyValue(id, UnsafeMutableRawPointer(eq), UnsafeMutableRawPointer(kc), UnsafeMutableRawPointer(md))
                    }
                }
            }
            let code = UInt16(truncatingIfNeeded: keyCode)
            guard status == .success, code != 0xFFFF, modifiers != 0 || code != 0 else { continue }
            keys.append(SymbolicHotKey(id: id, virtualKeyCode: code, modifiers: modifiers, isEnabled: isSymbolicHotKeyEnabled?(id) ?? true))
        }
        return keys
    }

    @discardableResult
    public func setSymbolicHotKey(_ id: Int32, enabled: Bool) -> Bool {
        setSymbolicHotKeyEnabled?(id, enabled) == .success
    }

    public func isSymbolicHotKeyOn(_ id: Int32) -> Bool? {
        isSymbolicHotKeyEnabled?(id)
    }
}
