import AppKit
import OrielCore
import Synchronization
import Testing
@testable import Upload

/// Never authenticates; the coordinator tests do not sign in.
@MainActor
private final class RefusingAuthenticator: WebAuthenticating {
    func authenticate(url _: URL, callbackScheme _: String) async throws -> URL {
        throw UploadError.cancelled
    }
}

@MainActor
struct UploadCoordinatorTests {
    private func coordinator(_ settings: TemporarySettings) -> UploadCoordinator {
        let secrets = InMemorySecrets()
        return UploadCoordinator(
            settings: settings.store, secrets: secrets, service: UploadService(secrets: secrets), authenticator: RefusingAuthenticator()
        )
    }

    @Test func theDestinationMenuListsTheDefaultFirstAndSaysWhichWasChosen() throws {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let coordinator = coordinator(settings)
        let nas = coordinator.destinations.add(.webDAV)
        let box = coordinator.destinations.add(.dropbox)
        coordinator.destinations.makeDefault(box.id)
        let chosen = Mutex<UUID?>(nil)
        let menu = coordinator.destinationMenu { id in chosen.withLock { $0 = id } }
        #expect(menu.items.map(\.title) == ["Upload to Dropbox", "Upload to WebDAV"])
        #expect(coordinator.isConfigured)
        // What choosing the item does; `performActionForItem` would need a running NSApplication.
        let item = try #require(menu.items.last)
        let action = try #require(item.action)
        _ = (item.target as? NSObject)?.perform(action, with: item)
        #expect(chosen.withLock { $0 } == nas.id)
    }

    @Test func withoutDestinationsTheMenuSaysSo() {
        let settings = TemporarySettings()
        defer { settings.remove() }
        let coordinator = coordinator(settings)
        let menu = coordinator.destinationMenu { _ in }
        #expect(menu.items.map(\.title) == ["No Upload Destinations"])
        #expect(menu.items.first?.isEnabled == false)
        #expect(!coordinator.isConfigured)
    }

    @Test func namesLoseWhatFilesCannotHave() {
        #expect(UploadCoordinator.safeName("a/b:c?") == "a-b-c-")
        #expect(UploadCoordinator.safeName("  ") == "Oriel")
    }
}
