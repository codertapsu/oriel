import Foundation
@testable import Licensing
import Testing

/// Pro unlocks only from a verified purchase of the Pro product that was never refunded (PLAN §19).
struct ProEntitlementTests {
    private let pro = "com.codertapsu.oriel.pro"

    @Test func aVerifiedPurchaseUnlocksPro() {
        #expect(ProEntitlement.isUnlocked(by: [.init(productID: pro, isVerified: true)], productID: pro))
    }

    @Test func nothingBoughtKeepsItLocked() {
        #expect(!ProEntitlement.isUnlocked(by: [], productID: pro))
    }

    /// A transaction whose signature fails is ignored, whatever it claims.
    @Test func anUnverifiedTransactionNeverUnlocks() {
        #expect(!ProEntitlement.isUnlocked(by: [.init(productID: pro, isVerified: false)], productID: pro))
    }

    /// A refund revokes the purchase: Pro locks again, and the user's work stays.
    @Test func aRefundLocksItAgain() {
        let refunded = ProEntitlement.Record(productID: pro, isVerified: true, revocationDate: Date())
        #expect(!ProEntitlement.isUnlocked(by: [refunded], productID: pro))
    }

    @Test func anotherProductDoesNotUnlockPro() {
        #expect(!ProEntitlement.isUnlocked(by: [.init(productID: "com.codertapsu.oriel.tip", isVerified: true)], productID: pro))
    }
}

private extension ProEntitlement.Record {
    init(productID: String, isVerified: Bool) {
        self.init(productID: productID, isVerified: isVerified, revocationDate: nil)
    }
}
