import Foundation

/// What decides whether Oriel Pro is unlocked, from the App Store's transactions (PLAN §19). Pure, so the rule is tested
/// without the App Store: a transaction for the Pro product that Apple's signature verifies and that was never refunded or
/// revoked unlocks Pro, for good. An unverified one never does.
nonisolated enum ProEntitlement {
    /// One transaction, as far as the rule needs it.
    struct Record: Sendable, Equatable {
        var productID: String
        var isVerified: Bool
        var revocationDate: Date?
    }

    static func isUnlocked(by records: [Record], productID: String) -> Bool {
        records.contains { $0.productID == productID && $0.isVerified && $0.revocationDate == nil }
    }
}
