/// One place to decide whether a feature is shown: the OS has it, this Mac can do it, and the user wants it
/// (PLAN §11). UI for a closed gate is hidden, not disabled.
public struct FeatureGate: Sendable, Equatable {
    public let isOpen: Bool
    /// Why the gate is closed, for Diagnostics.
    public let reason: String?

    public static let open = FeatureGate(isOpen: true, reason: nil)

    public static func closed(_ reason: String) -> FeatureGate {
        FeatureGate(isOpen: false, reason: reason)
    }

    /// The first closed condition wins.
    public static func all(_ conditions: (Bool, String)...) -> FeatureGate {
        for (isMet, reason) in conditions where !isMet {
            return .closed(reason)
        }
        return .open
    }
}
