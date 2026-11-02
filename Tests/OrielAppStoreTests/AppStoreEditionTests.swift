import Foundation
@testable import OrielAppStore
import OrielCore
import Permissions
import Testing

/// The App Store edition, tested inside its own sandbox (PLAN §19): what the App Store's rules exclude is not in the
/// bundle, and what the sandbox cannot be granted is not asked for.
@MainActor
struct AppStoreEditionTests {
    private let bundle = Bundle.main.bundleURL

    @Test func itRunsInTheSandbox() {
        #expect(Sandbox.isActive)
        #expect(Entitlements.value(of: "com.apple.security.app-sandbox") as? Bool == true)
        #expect(Entitlements.value(of: "com.apple.security.network.client") as? Bool == true)
    }

    /// No root helper and no command-line tool: the App Store allows neither (App Review Guidelines 2.4.5).
    @Test func itShipsNoHelperAndNoCLI() {
        let contents = bundle.appending(path: "Contents")
        #expect(!FileManager.default.fileExists(atPath: contents.appending(path: "Library/LaunchDaemons").path))
        #expect(!FileManager.default.fileExists(atPath: contents.appending(path: "Helpers/oriel").path))
        #expect(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }

    /// App Review rejects private APIs (Guidelines 2.5.1): the edition links no PrivateAPIs and names none of its symbols.
    @Test func itNamesNoPrivateSymbol() throws {
        let executable = try #require(Bundle.main.executableURL)
        let data = try Data(contentsOf: executable)
        for symbol in ["SLSMainConnectionID", "SLSCopyManagedDisplaySpaces", "CGSSetSymbolicHotKeyEnabled", "_AXUIElementGetWindow"] {
            #expect(data.range(of: Data(symbol.utf8)) == nil, "\(symbol) is in the executable")
        }
    }

    /// The sandbox cannot be granted Accessibility, so the edition never asks for it; it needs Screen Recording instead.
    @Test func itNeverAsksForAccessibility() {
        #expect(!PermissionKind.available.contains(.accessibility))
        #expect(PermissionKind.screenRecording.isRequired)
        #expect(!PermissionKind.accessibility.isRequired)
    }

    /// The feature tour shows this edition's tools only, and promises nothing its sandbox rules out (PLAN §19).
    @Test func theTourShowsOnlyWhatThisEditionHas() throws {
        let suiteName = "com.codertapsu.oriel.tests.tour.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let hub = try FeatureHub(
            settings: SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName))),
            permissions: PermissionCenter(),
            keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests")
        )
        #expect(hub.guides.tools.map(\.id) == ["clipboard-history", "disk-analyzer", "color-picker", "screen-ruler"])
        let text = (hub.guides.features + hub.guides.tools)
            .flatMap { [$0.summary] + $0.highlights.map(\.detail) }
            .joined(separator: " ")
        for promise in ["SFTP", "keys you press", "Oriel scrolls", "paste it into the app"] {
            #expect(!text.contains(promise), "\(promise)")
        }
    }
}
