import Foundation
@testable import Oriel
import OrielCore
import Permissions
import Testing

/// Every action and command in the app, from the app's own table, the features and all the tools: ids are unique, so
/// no two share a stored shortcut, and default shortcuts are unique, so none fails to register because of another
/// (PLAN §6.5).
@MainActor
struct AllCommandsTests {
    @Test func idsAndDefaultShortcutsAreUnique() throws {
        let suiteName = "com.codertapsu.oriel.tests.commands.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
        let hub = FeatureHub(
            settings: settings,
            permissions: PermissionCenter(),
            keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests")
        )
        let commands = hub.commands + hub.modules.flatMap(\.commands)
        let ids = AppAction.allCases.map(\.rawValue) + commands.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids: \(duplicates(ids))")

        var owners: [KeyCombo: [String]] = [:]
        for action in AppAction.shortcutActions {
            if let combo = action.defaultShortcut {
                owners[combo, default: []].append(action.rawValue)
            }
        }
        for command in commands {
            if let combo = command.defaultShortcut {
                owners[combo, default: []].append(command.id)
            }
        }
        let clashes = owners.filter { $0.value.count > 1 }.map { "\($0.key): \($0.value.joined(separator: ", "))" }
        #expect(clashes.isEmpty, "default shortcuts taken twice: \(clashes)")
        #expect(commands.count > 30, "every tool contributes its commands")
    }

    /// Tools route their own `oriel://` URLs; none may claim a route the app's table or another command already has.
    @Test func routesAreUnique() throws {
        let suiteName = "com.codertapsu.oriel.tests.routes.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
        let hub = FeatureHub(
            settings: settings,
            permissions: PermissionCenter(),
            keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests")
        )
        let routes = (hub.commands + hub.modules.flatMap(\.commands)).compactMap(\.route)
        #expect(Set(routes).count == routes.count, "duplicate routes: \(duplicates(routes))")
        for route in routes {
            let url = try #require(URL(string: "oriel://\(route)"))
            #expect(AppAction(url: url) == nil, "oriel://\(route) is already an app action")
        }
    }

    private func duplicates(_ values: [String]) -> [String] {
        Dictionary(grouping: values, by: \.self).filter { $0.value.count > 1 }.keys.sorted()
    }
}
