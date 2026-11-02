import AppKit
import Observation
import OrielCore
import os
import StoreKit

/// Oriel Pro as a one-time, non-consumable App Store purchase (PLAN §19). The App Store's signed transactions, which
/// macOS keeps on the Mac, are the only record: there is no server and no receipt file, and Pro stays unlocked offline.
/// From launch to quit it listens for transactions made elsewhere (on another Mac, an approved Ask to Buy, a refund) and
/// keeps `ProAccess` in step. The last answer is remembered only so that the first moments after launch show the right
/// state; the App Store's record replaces it a moment later.
@Observable
public final class ProStore {
    /// The product in App Store Connect and in Oriel.storekit.
    public static let productID = "com.codertapsu.oriel.pro"

    /// The product, once the App Store has described it: its localized name and price.
    public private(set) var product: Product?
    public private(set) var isPurchasing = false
    /// A purchase waiting for a parent's approval (Ask to Buy).
    public private(set) var isPending = false
    /// What went wrong with the last purchase or restore, in a sentence.
    public private(set) var lastError: String?

    @ObservationIgnored private let access: ProAccess
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let log = Log.logger("pro")
    private static let unlockedKey = "pro.lastKnownUnlocked"

    public init(access: ProAccess = .shared, defaults: UserDefaults = .standard) {
        self.access = access
        self.defaults = defaults
    }

    /// Settles `ProAccess` from the last answer at once, starts listening, and asks the App Store.
    public func start() {
        access.setUnlocked(defaults.bool(forKey: Self.unlockedKey))
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refresh()
            await loadProduct()
        }
    }

    /// Reads the transactions the App Store has for this Apple Account on this Mac, which works offline.
    public func refresh() async {
        var records: [ProEntitlement.Record] = []
        for await result in Transaction.currentEntitlements(for: Self.productID) {
            records.append(Self.record(result))
        }
        setUnlocked(ProEntitlement.isUnlocked(by: records, productID: Self.productID))
    }

    public func loadProduct() async {
        guard product == nil else { return }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            log.error("the Pro product could not be loaded: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Buys Pro with the App Store's sheet attached to `window`; macOS shows the sheet only over a window.
    public func purchase(confirmIn window: NSWindow) async {
        await purchase { product in try await product.purchase(confirmIn: window) }
    }

    /// Buys Pro through `buy`, such as SwiftUI's `PurchaseAction`, which finds the window itself.
    public func purchase(_ buy: (Product) async throws -> Product.PurchaseResult) async {
        await loadProduct()
        guard let product else {
            lastError = "The App Store did not answer. Check your connection and try again."
            return
        }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            switch try await buy(product) {
            case let .success(verification):
                await handle(verification)
            case .pending:
                isPending = true
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restore Purchases: has the App Store send this Apple Account's transactions again. It may ask the user to sign in.
    public func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    /// A purchase or refund as it happens: decided from the transaction itself, since the list `refresh` reads can lag
    /// behind it for a moment.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else {
            log.error("a transaction failed the App Store's verification and was ignored")
            return
        }
        if transaction.productID == Self.productID {
            setUnlocked(ProEntitlement.isUnlocked(by: [Self.record(result)], productID: Self.productID))
        }
        await transaction.finish()
    }

    private func setUnlocked(_ unlocked: Bool) {
        if unlocked {
            isPending = false
        }
        defaults.set(unlocked, forKey: Self.unlockedKey)
        access.setUnlocked(unlocked)
    }

    private static func record(_ result: VerificationResult<Transaction>) -> ProEntitlement.Record {
        switch result {
        case let .verified(transaction):
            ProEntitlement.Record(productID: transaction.productID, isVerified: true, revocationDate: transaction.revocationDate)
        case let .unverified(transaction, _):
            ProEntitlement.Record(productID: transaction.productID, isVerified: false, revocationDate: transaction.revocationDate)
        }
    }
}
