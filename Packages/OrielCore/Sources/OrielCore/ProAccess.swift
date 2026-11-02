import Foundation
import Observation

/// Whether Oriel Pro is unlocked, and the one question every feature asks before a Pro feature runs (PLAN §19). The app
/// decides `isUnlocked`: the App Store edition from its one-time purchase, the Developer ID edition always. Asked about a
/// locked feature, `check` hands it to `onLocked`, which shows Settings → Oriel Pro naming it.
@MainActor
@Observable
public final class ProAccess {
    /// The one the app sets and every feature asks.
    public static let shared = ProAccess()

    /// Posted on the main thread when `isUnlocked` changes, for AppKit views that show what is locked.
    public static let didChangeNotification = Notification.Name("ProAccess.didChange")

    public private(set) var isUnlocked: Bool
    /// Shows what Pro adds; the app sets it.
    @ObservationIgnored public var onLocked: (@MainActor (ProFeature) -> Void)?

    public init(isUnlocked: Bool = true) {
        self.isUnlocked = isUnlocked
    }

    public func setUnlocked(_ unlocked: Bool) {
        guard unlocked != isUnlocked else { return }
        isUnlocked = unlocked
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    /// Whether `feature` may run now, without asking.
    public func allows(_ feature: ProFeature) -> Bool {
        isUnlocked
    }

    /// Whether `feature` may run; when it may not, shows what Pro adds and returns false.
    @discardableResult
    public func check(_ feature: ProFeature) -> Bool {
        guard !isUnlocked else { return true }
        onLocked?(feature)
        return false
    }
}
