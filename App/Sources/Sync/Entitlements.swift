import Security

/// The app's own entitlements, read from its code signature, for features that exist only when the build carries one.
enum Entitlements {
    static func value(of name: String) -> Any? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        return SecTaskCopyValueForEntitlement(task, name as CFString, nil)
    }
}
