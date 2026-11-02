import Foundation
@testable import Oriel
import OrielCore
import Permissions
import Testing

/// The feature tour's pages (PLAN §19): one per feature and tool, each described and opening its Settings pane, each
/// Try It naming a real action or command, and every Pro feature of the features and tools on a page.
@MainActor
struct FeatureTourTests {
    private func hub() throws -> FeatureHub {
        let suiteName = "com.codertapsu.oriel.tests.tour.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        return try FeatureHub(
            settings: SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName))),
            permissions: PermissionCenter(),
            keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests")
        )
    }

    @Test func everyFeatureAndToolHasADescribedPage() throws {
        let hub = try hub()
        let guides = hub.guides.features + hub.guides.tools
        let ids = guides.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate pages")
        #expect(hub.modules.allSatisfy { $0.guide != nil }, "every tool brings its page")
        for guide in guides {
            #expect(!guide.title.isEmpty && !guide.summary.isEmpty && !guide.highlights.isEmpty, "\(guide.id)")
            #expect(Set(guide.highlights.map(\.id)).count == guide.highlights.count, "\(guide.id): highlights repeat")
        }
        let panes = Set(hub.settingsPanes.map(\.id))
        #expect(ids.filter { !panes.contains($0) }.isEmpty, "Settings… opens the page's pane")
    }

    @Test func tryItRunsARealCommand() throws {
        let hub = try hub()
        let commands = Set((hub.commands + hub.modules.flatMap(\.commands)).map(\.id) + AppAction.allCases.map(\.rawValue))
        let named = (hub.guides.features + hub.guides.tools).compactMap(\.commandID)
        #expect(named.filter { !commands.contains($0) }.isEmpty, "Try It names no command")
        #expect(named.count >= 9)
    }

    @Test func theProFeaturesOfEveryFeatureAndToolAreOnItsPages() throws {
        let hub = try hub()
        let shown = Set((hub.guides.features + hub.guides.tools).flatMap(\.highlights).compactMap(\.proFeature))
        #expect(shown.isSubset(of: Set(hub.proFeatures)))
        // Settings sync belongs to the app, not to a feature or tool.
        #expect(hub.proFeatures.filter { $0 != .settingsSync && !shown.contains($0) }.map(\.id).isEmpty)
    }
}
