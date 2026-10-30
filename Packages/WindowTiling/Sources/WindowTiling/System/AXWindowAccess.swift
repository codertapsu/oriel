import ApplicationServices
import CoreGraphics
import Foundation

/// Window Tiling's Accessibility calls (CLAUDE.md rule 6). They are synchronous IPC to the app in front, so they run
/// only on the AX actor, `WindowMover`, never on the main thread, and every element gets a 0.25 s messaging timeout:
/// a hung app costs at most that per call.
nonisolated struct AXWindowAccess: WindowAccessing {
    static let messagingTimeout: Float = 0.25
    /// Not in the public headers. Assistive apps such as VoiceOver turn it on, and while it is on Chromium and Electron
    /// apps animate every frame change, so the window would land late and short. Turned off for the move and back on
    /// afterwards, as other window managers do (Rectangle's and Amethyst's handling was read, not copied).
    static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"
    /// `kAXFullScreenAttribute` is not in the public headers either.
    static let fullScreenAttribute = "AXFullScreen"

    private static let snapshotAttributes = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute, fullScreenAttribute, kAXMinimizedAttribute,
    ]
    private static let frameAttributes = [kAXPositionAttribute, kAXSizeAttribute]

    /// The focused window, else the main window (an app whose focus is in a floating palette). Never one of Oriel's own:
    /// macOS would answer that request inside Oriel, on this thread (`OwnWindowAccess` handles them).
    func focusedWindow(of pid: Int32) -> WindowLookup<AXUIElement> {
        guard pid != OwnWindowTiler.ownPID else { return .noWindow }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var value: CFTypeRef?
            switch AXUIElementCopyAttributeValue(app, attribute as CFString, &value) {
            case .success:
                guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
                let window = unsafeDowncast(value, to: AXUIElement.self)
                AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)
                return .found(window)
            case .cannotComplete, .apiDisabled:
                return .refused
            default:
                continue
            }
        }
        return .noWindow
    }

    func key(of window: AXUIElement) -> WindowIdentity {
        WindowIdentity(element: window)
    }

    /// Every attribute in one round trip, plus whether position and size can be set.
    func snapshot(of window: AXUIElement) -> WindowSnapshot? {
        guard let values = Self.values(Self.snapshotAttributes, of: window) else { return nil }
        let origin = Self.point(values[2])
        let size = Self.size(values[3])
        let frame = origin.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } }
        return WindowSnapshot(
            frame: frame ?? .zero,
            role: values[0] as? String,
            subrole: values[1] as? String,
            isFullScreen: values[4] as? Bool ?? false,
            isMinimized: values[5] as? Bool ?? false,
            canMove: frame != nil && Self.isSettable(kAXPositionAttribute, of: window),
            canResize: frame != nil && Self.isSettable(kAXSizeAttribute, of: window)
        )
    }

    func frame(of window: AXUIElement) -> CGRect? {
        guard let values = Self.values(Self.frameAttributes, of: window),
              let origin = Self.point(values[0]),
              let size = Self.size(values[1])
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    @discardableResult
    func setSize(_ size: CGSize, of window: AXUIElement) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }

    @discardableResult
    func setPosition(_ origin: CGPoint, of window: AXUIElement) -> Bool {
        var origin = origin
        guard let value = AXValueCreate(.cgPoint, &origin) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    func withEnhancedUserInterfaceOff<Result>(pid: Int32, _ body: () -> Result) -> Result {
        guard pid != OwnWindowTiler.ownPID else { return body() }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
        let attribute = Self.enhancedUserInterfaceAttribute as CFString
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, attribute, &value) == .success, value as? Bool == true else { return body() }
        AXUIElementSetAttributeValue(app, attribute, NSNumber(value: false))
        defer { AXUIElementSetAttributeValue(app, attribute, NSNumber(value: true)) }
        return body()
    }

    // MARK: Values

    /// The attributes' values, in order; an attribute the window lacks comes back as an `AXValue` of the error type.
    private static func values(_ attributes: [String], of element: AXUIElement) -> [AnyObject]? {
        var values: CFArray?
        let names = attributes as CFArray
        guard AXUIElementCopyMultipleAttributeValues(element, names, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
              let array = values as [AnyObject]?, array.count == attributes.count
        else { return nil }
        return array
    }

    private static func isSettable(_ attribute: String, of element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private static func point(_ object: AnyObject) -> CGPoint? {
        guard let value = axValue(object, type: .cgPoint) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private static func size(_ object: AnyObject) -> CGSize? {
        guard let value = axValue(object, type: .cgSize) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private static func axValue(_ object: AnyObject, type: AXValueType) -> AXValue? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        let value = unsafeDowncast(object, to: AXValue.self)
        return AXValueGetType(value) == type ? value : nil
    }
}
