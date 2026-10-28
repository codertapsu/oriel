import Foundation
import OrielCore
import OrielTestSupport
@testable import OrielTranslation
import Testing

/// Touches the login keychain, so it runs with the TCC tests on the dev Mac only (`ORIEL_TCC_TESTS=1`).
@MainActor
struct KeychainIntegrationTests {
    @Test(.requiresTCC)
    func providerKeysRoundTripThroughTheKeychain() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let keychain = KeychainStore(prefix: "com.codertapsu.oriel.tests")
        let id = ProviderID(rawValue: "test-\(UUID().uuidString)")
        defer { try? keychain.remove(service: id.keychainService) }
        let registry = ProviderRegistry(settings: settings.store, secrets: keychain, http: .makeDefault())

        try registry.setAPIKey("sk-live-test", for: id)
        #expect(keychain.string(service: "provider.\(id.rawValue)") == "sk-live-test")
        #expect(registry.apiKey(for: id)?.value == "sk-live-test")
        try registry.setAPIKey(nil, for: id)
        #expect(registry.apiKey(for: id) == nil)
    }
}
