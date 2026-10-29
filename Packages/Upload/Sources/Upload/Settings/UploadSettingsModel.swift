import AppKit
import Foundation
import Observation
import OrielCore
import SwiftUI

/// The state and actions behind Settings → Upload: editing destinations, their secrets (Keychain only), Test
/// Connection, Dropbox and Google Drive sign-in, and choosing folders and key files.
@Observable
final class UploadSettingsModel {
    /// A test or a sign-in.
    enum Activity: Equatable {
        case running
        case succeeded(String)
        case failed(String)
    }

    @ObservationIgnored unowned let coordinator: UploadCoordinator
    var tests: [UUID: Activity] = [:]
    var signIns: [UUID: Activity] = [:]
    var secretDrafts: [UUID: String] = [:]
    var secretMessages: [UUID: String] = [:]
    /// The rows that are open; a new destination opens, ready to fill in.
    var expanded: Set<UUID> = []
    /// The destination whose Delete is waiting for confirmation.
    var pendingRemoval: UUID?
    /// Changes whenever the Keychain caches below do, so the views reading them draw again.
    private(set) var keychainRevision = 0
    @ObservationIgnored private var storedSecrets: [UUID: Bool] = [:]
    @ObservationIgnored private var storedTokens: [UUID: OAuthTokens?] = [:]

    /// The sample `{name}` and `{random}` the name previews use.
    static let sampleName = "Safari"
    static let sampleRandom = "8d3f6c0b9a7e4f21b5c2d9e0a1f3b4c5"

    init(coordinator: UploadCoordinator) {
        self.coordinator = coordinator
    }

    private var store: UploadDestinationStore {
        coordinator.destinations
    }

    var settings: SettingsStore {
        store.settings
    }

    var destinations: [UploadDestination] {
        store.destinations
    }

    var defaultID: UUID? {
        store.defaultDestination?.id
    }

    var defaultSelection: Binding<UUID?> {
        Binding(get: { [store] in store.defaultDestination?.id }, set: { [store] in $0.map(store.makeDefault) })
    }

    func binding(for id: UUID) -> Binding<UploadDestination> {
        let fallback = store.destination(id) ?? UploadDestination(id: id, name: "", target: .empty(.s3))
        return Binding(get: { [store] in store.destination(id) ?? fallback }, set: { [store] in store.update($0) })
    }

    // MARK: Destinations

    func add(_ kind: UploadDestinationKind) {
        let destination = store.add(kind)
        expanded.insert(destination.id)
    }

    /// Deletes the destination and its secrets at once; a signed-in service's tokens are revoked afterwards, in the
    /// background.
    func remove(_ id: UUID) {
        pendingRemoval = nil
        guard let destination = store.destination(id) else { return }
        let signIn = destination.kind.usesOAuth ? tokens(id) : nil
        expanded.remove(id)
        tests[id] = nil
        signIns[id] = nil
        store.remove(id)
        forgetKeychainState(id)
        if let signIn {
            Task { await coordinator.service.revoke(signIn, of: destination) }
        }
    }

    func makeDefault(_ id: UUID) {
        store.makeDefault(id)
    }

    func test(_ id: UUID) {
        guard let destination = store.destination(id) else { return }
        tests[id] = .running
        Task {
            do {
                tests[id] = try await .succeeded(coordinator.service.testConnection(destination))
            } catch {
                tests[id] = .failed(UploadError.from(error).localizedDescription)
            }
            refreshTokens(id)
        }
    }

    // MARK: Secrets

    func hasSecret(_ id: UUID) -> Bool {
        _ = keychainRevision
        if let known = storedSecrets[id] {
            return known
        }
        guard let kind = store.destination(id)?.kind, let secret = UploadSecret.secret(for: kind),
              secret != .oauthTokens else { return false }
        let stored = (try? store.secrets.string(secret, for: id)) != nil
        storedSecrets[id] = stored
        return stored
    }

    func saveSecret(_ id: UUID) {
        guard let kind = store.destination(id)?.kind, let secret = UploadSecret.secret(for: kind) else { return }
        let draft = secretDrafts[id] ?? ""
        do {
            try store.secrets.setString(draft.isEmpty ? nil : draft, secret, for: id)
            storedSecrets[id] = !draft.isEmpty
            secretDrafts[id] = ""
            secretMessages[id] = draft.isEmpty ? "Removed from the keychain." : "Saved in the keychain."
        } catch {
            secretMessages[id] = "Couldn't save it: \(error.localizedDescription)"
        }
        keychainRevision += 1
    }

    func removeSecret(_ id: UUID) {
        secretDrafts[id] = ""
        saveSecret(id)
    }

    // MARK: Sign-in

    /// The tokens kept for `id`, read once from the Keychain.
    func tokens(_ id: UUID) -> OAuthTokens? {
        _ = keychainRevision
        if let known = storedTokens[id] {
            return known
        }
        let tokens = (try? store.secrets.tokens(for: id)) ?? nil
        storedTokens[id] = .some(tokens)
        return tokens
    }

    func hasTokens(_ id: UUID) -> Bool {
        tokens(id) != nil
    }

    /// Opens the service's sign-in sheet, trades its code for tokens and keeps them.
    func signIn(_ id: UUID) {
        guard let destination = store.destination(id) else { return }
        signIns[id] = .running
        Task {
            do {
                let endpoints = await coordinator.service.oauthEndpoints
                let authorization = try UploadService.authorization(for: destination, endpoints: endpoints)
                let callback = try await coordinator.authenticator.authenticate(
                    url: authorization.url,
                    callbackScheme: authorization.callbackScheme
                )
                let code = try OAuthCallback.code(from: callback, expectedState: authorization.state, service: authorization.service)
                let tokens = try await coordinator.service.completeSignIn(destination, code: code, pkce: authorization.pkce)
                storedTokens[id] = .some(tokens)
                keychainRevision += 1
                signIns[id] = Self.signInOutcome(tokens, for: destination)
            } catch {
                let failure = UploadError.from(error)
                signIns[id] = failure.isCancellation ? nil : .failed(failure.localizedDescription)
            }
        }
    }

    func signOut(_ id: UUID) {
        guard let destination = store.destination(id) else { return }
        Task {
            do {
                try await coordinator.service.signOut(destination)
                signIns[id] = nil
            } catch {
                signIns[id] = .failed(UploadError.from(error).localizedDescription)
            }
            storedTokens[id] = .some(nil)
            keychainRevision += 1
        }
    }

    /// What a finished sign-in says, warning when the service granted less than uploads need: a Dropbox app without
    /// the permissions ticked, or a Google consent screen where the Drive box was left clear.
    static func signInOutcome(_ tokens: OAuthTokens, for destination: UploadDestination) -> Activity {
        let who = tokens.account.map { "Signed in as \($0)." } ?? "Signed in."
        switch destination.target {
        case .dropbox:
            let missing = DropboxConfiguration.requiredScopes.filter { !tokens.grants($0) }
            guard missing.isEmpty else {
                return .failed(
                    "\(who) Your Dropbox app lacks \(missing.joined(separator: ", ")): turn on the permissions in the App Console's "
                        + "Permissions tab, then sign in again."
                )
            }
        case let .googleDrive(configuration):
            guard tokens.grants(configuration.access.scope) else {
                return .failed("\(who) Google Drive access wasn't allowed: sign in again and tick the Google Drive box.")
            }
        default:
            break
        }
        return .succeeded(who)
    }

    // MARK: Files and folders

    /// Lets the user pick the shared folder, and remembers it with a bookmark.
    func chooseFolder(_ id: UUID) {
        guard var destination = store.destination(id), case var .sharedFolder(configuration) = destination.target else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the folder uploads are copied into: a server share, a synced folder or a folder on this Mac."
        if !configuration.path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: configuration.path, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        configuration.path = url.path
        configuration.bookmark = try? SharedFolderAccess.bookmark(for: url)
        destination.target = .sharedFolder(configuration)
        store.update(destination)
        tests[id] = nil
    }

    /// Lets the user pick a private key for SFTP. Only its path is kept; Oriel never reads the key.
    func chooseKeyFile(_ id: UUID) {
        guard var destination = store.destination(id), case var .sftp(configuration) = destination.target else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = "Use Key"
        panel.message = "Choose the private key ssh should use for this server (not the .pub file)."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh", directoryHint: .isDirectory)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        configuration.identityFile = (url.path as NSString).abbreviatingWithTildeInPath
        destination.target = .sftp(configuration)
        store.update(destination)
    }

    // MARK: Previews

    /// The name an upload would get now, for the caption under the template.
    static func namePreview(_ template: String, fileExtension: String = "png", now: Date = Date()) -> String {
        let context = UploadNameTemplate.Context(name: sampleName, date: now, random: sampleRandom)
        return UploadPath.joined(UploadNameTemplate.render(template, context: context, fileExtension: fileExtension))
    }

    /// The link an upload would get from `template`, or nil when there is none to show.
    static func linkPreview(_ template: String, nameTemplate: String) -> String? {
        let context = UploadNameTemplate.Context(name: sampleName, date: Date(), random: sampleRandom)
        let path = UploadNameTemplate.render(nameTemplate, context: context, fileExtension: "png")
        return UploadLinkTemplate.link(template, path: path)?.absoluteString
    }

    // MARK: Keychain caches

    private func refreshTokens(_ id: UUID) {
        guard store.destination(id)?.kind.usesOAuth == true else { return }
        storedTokens[id] = nil
        keychainRevision += 1
    }

    private func forgetKeychainState(_ id: UUID) {
        storedSecrets[id] = nil
        storedTokens[id] = nil
        secretDrafts[id] = nil
        secretMessages[id] = nil
        keychainRevision += 1
    }
}
