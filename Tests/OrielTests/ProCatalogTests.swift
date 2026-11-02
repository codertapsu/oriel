import Foundation
@testable import Oriel
import OrielCore
import Permissions
import Testing

/// The Pro catalog Settings → Oriel Pro lists (PLAN §19): ids are unique, every feature says what it adds, and every
/// gated command and menu action names a feature that is in it.
@MainActor
struct ProCatalogTests {
    @Test func featuresAreUniqueDescribedAndCoverEveryGate() throws {
        let suiteName = "com.codertapsu.oriel.tests.pro.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
        let hub = FeatureHub(
            settings: settings,
            permissions: PermissionCenter(),
            keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests")
        )
        let features = hub.proFeatures
        let ids = features.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids")
        #expect(features.allSatisfy { !$0.title.isEmpty && !$0.summary.isEmpty })

        let catalog = Set(features)
        let gates = (hub.commands + hub.modules.flatMap(\.commands)).compactMap(\.proFeature)
            + AppAction.allCases.compactMap(\.proFeature)
        #expect(gates.filter { !catalog.contains($0) }.map(\.id).isEmpty, "gated, but not in the catalog")
        #expect(gates.count >= 5)
    }
}
