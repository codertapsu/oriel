import ApplicationServices
import CoreGraphics
import Foundation

/// Reading and writing AX attributes. Called only from the AX actors: `AXClient` for windows, `DockAccessibility` for the
/// Dock.
nonisolated enum AXAttributeReader {
    /// `kAXFullScreenAttribute` is not in the public headers; this is its value.
    static let fullScreenAttribute = "AXFullScreen"

    private static let windowAttributes = [
        kAXTitleAttribute, kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, fullScreenAttribute,
        kAXPositionAttribute, kAXSizeAttribute,
    ]

    /// Every attribute of a window record in one round trip (`AXUIElementCopyMultipleAttributeValues`).
    /// Nil when the app did not answer; `windowID` and `isListed` are the caller's to fill in.
    static func record(of window: AXUIElement) -> AXWindowRecord? {
        var values: CFArray?
        let names = windowAttributes as CFArray
        guard AXUIElementCopyMultipleAttributeValues(window, names, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
              let array = values as [AnyObject]?, array.count == windowAttributes.count
        else {
            return nil
        }
        let position = point(array[5])
        let size = size(array[6])
        let frame = position.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } }
        return AXWindowRecord(
            windowID: nil,
            title: array[0] as? String ?? "",
            role: array[1] as? String,
            subrole: array[2] as? String,
            frame: frame,
            isMinimized: array[3] as? Bool ?? false,
            isFullScreen: array[4] as? Bool ?? false,
            isListed: true
        )
    }

    static func string(_ attribute: String, of element: AXUIElement) -> String? {
        value(attribute, of: element) as? String
    }

    static func bool(_ attribute: String, of element: AXUIElement) -> Bool? {
        value(attribute, of: element) as? Bool
    }

    /// An attribute whose value is another element (the focused window, a window's close button).
    static func element(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        guard let object = value(attribute, of: element), CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(object, to: AXUIElement.self)
    }

    /// An attribute whose value is a list of elements (children, selected children).
    static func elements(_ attribute: String, of element: AXUIElement) -> [AXUIElement]? {
        value(attribute, of: element) as? [AXUIElement]
    }

    static func value(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    @discardableResult
    static func set(_ attribute: String, to flag: Bool, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, NSNumber(value: flag)) == .success
    }

    @discardableResult
    static func perform(_ action: String, on element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    static func point(_ object: AnyObject) -> CGPoint? {
        guard let value = axValue(object, type: .cgPoint) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    static func size(_ object: AnyObject) -> CGSize? {
        guard let value = axValue(object, type: .cgSize) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    /// The value as an `AXValue` of `type`. Attributes the window lacks arrive as `AXValue`s of the error type.
    private static func axValue(_ object: AnyObject, type: AXValueType) -> AXValue? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        let value = unsafeDowncast(object, to: AXValue.self)
        return AXValueGetType(value) == type ? value : nil
    }
}
