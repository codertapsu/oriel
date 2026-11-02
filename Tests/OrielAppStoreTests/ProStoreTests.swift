import Foundation
import Licensing
import OrielCore
import StoreKitTest
import Testing

/// Oriel Pro bought, refunded and found again against Oriel.storekit, inside the App Store edition (PLAN §19).
@MainActor
@Suite(.serialized)
struct ProStoreTests {
    private func session() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Oriel")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func store(_ access: ProAccess) throws -> ProStore {
        try ProStore(access: access, defaults: #require(UserDefaults(suiteName: "ProStoreTests.\(UUID().uuidString)")))
    }

    /// StoreKit delivers transactions asynchronously; waits up to two seconds for `condition`.
    private func eventually(_ condition: @MainActor () -> Bool) async throws -> Bool {
        for _ in 0 ..< 40 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func theProductCostsTenDollarsAndIsNotShared() async throws {
        _ = try session()
        let store = try store(ProAccess(isUnlocked: false))
        await store.loadProduct()
        let product = try #require(store.product)
        #expect(product.id == ProStore.productID)
        #expect(product.type == .nonConsumable)
        #expect(product.price == 10)
        #expect(!product.isFamilyShareable)
    }

    /// A purchase made elsewhere (another Mac, an approved Ask to Buy) reaches the running app through the transaction
    /// listener and unlocks Pro; a refund, arriving the same way, locks it again. The purchase sheet itself needs a
    /// window, which a test host has not, so the session buys.
    @Test func aPurchaseUnlocksProAndARefundLocksIt() async throws {
        let session = try session()
        let access = ProAccess(isUnlocked: false)
        let store = try store(access)
        store.start()
        let transaction = try await session.buyProduct(identifier: ProStore.productID)
        #expect(try await eventually { access.isUnlocked })
        try session.refundTransaction(identifier: UInt(transaction.id))
        #expect(try await eventually { !access.isUnlocked })
    }

    /// Pro survives a new launch: the transaction is on the Mac, and nothing needs the network.
    @Test func aNewLaunchFindsThePurchase() async throws {
        let session = try session()
        _ = try await session.buyProduct(identifier: ProStore.productID)
        let access = ProAccess(isUnlocked: false)
        let store = try store(access)
        #expect(try await eventually {
            Task { await store.refresh() }
            return access.isUnlocked
        })
    }
}
