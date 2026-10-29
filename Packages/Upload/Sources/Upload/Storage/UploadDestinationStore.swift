import Foundation
import OrielCore
import os

/// The destinations in settings and their secrets in the Keychain, for the coordinator and Settings → Upload.
///
/// It also takes in Oriel 0.1's single S3 setting (`UploadSettings.configuration` and its secret key), on launch and
/// whenever a bootstrap import writes it again: the setting becomes (or updates) the destination with
/// `UploadDestinationList.legacyID`, its secret key moves to that destination's account, and both old entries are
/// cleared, so the old setting works as an inbox and nothing is taken in twice.
@MainActor
public final class UploadDestinationStore {
    public let settings: SettingsStore
    let secrets: any UploadSecretStoring
    private var observer: NSObjectProtocol?
    private let log = Log.logger("upload")

    public init(settings: SettingsStore, secrets: any UploadSecretStoring) {
        self.settings = settings
        self.secrets = secrets
        takeInLegacySettings()
        observer = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: .main
        ) { [weak self] note in
            guard note.userInfo?["key"] as? String == UploadSettings.configuration.name else { return }
            MainActor.assumeIsolated {
                // A bootstrap import stores the secret key just after the setting; take both in once it is done.
                guard let self, self.settings.hasValue(UploadSettings.configuration) else { return }
                Task { @MainActor [weak self] in self?.takeInLegacySettings() }
            }
        }
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public var list: UploadDestinationList {
        get { settings[UploadSettings.destinations] }
        set { settings[UploadSettings.destinations] = newValue }
    }

    public var destinations: [UploadDestination] {
        list.destinations
    }

    public var defaultDestination: UploadDestination? {
        list.defaultDestination
    }

    public func destination(_ id: UUID) -> UploadDestination? {
        list.destination(id)
    }

    @discardableResult
    public func add(_ kind: UploadDestinationKind) -> UploadDestination {
        var list = list
        let destination = list.add(kind)
        self.list = list
        return destination
    }

    public func update(_ destination: UploadDestination) {
        var list = list
        guard list.destination(destination.id) != destination else { return }
        list.update(destination)
        self.list = list
    }

    /// Removes the destination and its secrets.
    public func remove(_ id: UUID) {
        var list = list
        list.remove(id)
        self.list = list
        do {
            try secrets.removeSecrets(for: id)
        } catch {
            log.error("a removed destination's secrets stayed in the keychain: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func makeDefault(_ id: UUID) {
        var list = list
        list.makeDefault(id)
        self.list = list
    }

    /// Takes Oriel 0.1's S3 setting and secret key into the list, then clears them. A keychain that cannot be read
    /// leaves the secret where it is, for the next launch.
    func takeInLegacySettings() {
        if settings.hasValue(UploadSettings.configuration) {
            let legacy = settings[UploadSettings.configuration]
            if legacy.hasContent {
                var list = list
                list.importLegacy(legacy)
                self.list = list
                log.notice("took the 0.1 S3 destination into the destination list")
            }
            settings.reset(UploadSettings.configuration)
        }
        moveLegacySecret()
    }

    private func moveLegacySecret() {
        let service = UploadSettings.keychainService
        let account = UploadSettings.keychainAccount
        do {
            guard let secret = try secrets.data(service: service, account: account), !secret.isEmpty,
                  destination(UploadDestinationList.legacyID) != nil
            else {
                return
            }
            try secrets.setData(secret, service: service, account: UploadSecret.secretKey.account(for: UploadDestinationList.legacyID))
            try secrets.setData(nil, service: service, account: account)
        } catch {
            log.error("the 0.1 S3 secret key could not be moved yet: \(error.localizedDescription, privacy: .public)")
        }
    }
}
