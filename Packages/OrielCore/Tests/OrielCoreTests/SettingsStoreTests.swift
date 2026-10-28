import Foundation
import OrielCore
import os
import Testing

@MainActor
struct SettingsStoreTests {
    private let suiteName = "com.codertapsu.oriel.tests.\(UUID().uuidString)"
    private static let width = SettingKey("tests.width", default: 42)
    private static let combo = SettingKey("tests.combo", default: KeyCombo(keyCode: KeyCode.space, modifiers: .command))

    @Test func returnsDefaultsUntilSetAndPersistsCodableValues() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        #expect(settings[Self.width] == 42)
        #expect(!settings.hasValue(Self.width))

        settings[Self.width] = 7
        settings[Self.combo] = KeyCombo(keyCode: KeyCode.ansi4, modifiers: [.control, .shift])
        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened[Self.width] == 7)
        #expect(reopened[Self.combo].description == "⌃⇧4")

        reopened.reset(Self.width)
        #expect(reopened[Self.width] == 42)
    }

    @Test func bindingsWriteThroughAndPrefixRemovalResets() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.binding(Self.width).wrappedValue = 99
        #expect(settings[Self.width] == 99)
        settings.removeAll(withPrefix: "tests.")
        #expect(settings[Self.width] == 42)
    }

    @Test func postsAChangeNotificationWithTheKeyName() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        // The observer block is @Sendable, so what it collects goes behind a lock.
        let names = OSAllocatedUnfairLock(initialState: [String]())
        let token = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: nil
        ) { note in
            let name = note.userInfo?["key"] as? String ?? ""
            names.withLock { $0.append(name) }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        settings[Self.width] = 1
        #expect(names.withLock { $0 } == ["tests.width"])
    }
}
