import AppKit
import OrielCore
import os
import SharedUI

/// "Upload" from the Quick Access Overlay and the editor (PLAN §7.8, §17): prepare the file off the main
/// thread, send it to the default destination (or the one chosen in `destinationMenu`), show its progress with
/// Cancel, copy the link in the destination's format, and say how it went.
@MainActor
public final class UploadCoordinator {
    /// The destinations and their secrets.
    public let destinations: UploadDestinationStore
    let service: UploadService
    let authenticator: any WebAuthenticating
    private let settings: SettingsStore
    /// Panels on screen, oldest first, so a second upload's panel sits above the first one's.
    private var panels: [UploadProgressPanel] = []
    private let log = Log.logger("upload")

    /// Settings → Upload's state, kept here so it survives switching panes.
    lazy var settingsModel = UploadSettingsModel(coordinator: self)

    /// How long an upload runs before its progress panel appears, so a quick one shows only the result.
    static let panelDelay: Duration = .milliseconds(300)

    public convenience init(settings: SettingsStore, keychain: KeychainStore) {
        self.init(settings: settings, secrets: keychain, service: UploadService(secrets: keychain), authenticator: WebAuthenticator())
    }

    init(settings: SettingsStore, secrets: any UploadSecretStoring, service: UploadService, authenticator: any WebAuthenticating) {
        self.settings = settings
        self.service = service
        self.authenticator = authenticator
        destinations = UploadDestinationStore(settings: settings, secrets: secrets)
    }

    /// Whether Upload has somewhere to go.
    public var isConfigured: Bool {
        destinations.defaultDestination != nil
    }

    /// Uploads a PNG of `image` to `destinationID`, or to the default destination, and returns its link; also copies
    /// the link and says so.
    @discardableResult
    public func upload(_ image: CGImage, scale: CGFloat = 2, name: String = "Oriel", to destinationID: UUID? = nil) async -> URL? {
        guard ProAccess.shared.check(.upload) else { return nil }
        let label = Self.safeName(name)
        return await run(to: destinationID) { service in
            try await service.prepare(image: image, scale: scale, name: label)
        }
    }

    /// Uploads any file (a recording, an export) and returns its link.
    @discardableResult
    public func upload(fileAt url: URL, to destinationID: UUID? = nil) async -> URL? {
        guard ProAccess.shared.check(.upload) else { return nil }
        let strips = (destinationID.flatMap(destinations.destination) ?? destinations.defaultDestination)?.stripsMetadata ?? true
        return await run(to: destinationID) { service in
            try await service.prepare(fileAt: url, stripsMetadata: strips)
        }
    }

    /// Tests the default destination, for callers that do not show Settings.
    public func testConnection() async -> String {
        guard let destination = destinations.defaultDestination else { return UploadError.noDestination.localizedDescription }
        do {
            return try await service.testConnection(destination)
        } catch {
            return UploadError.from(error).localizedDescription
        }
    }

    /// A menu with an item per destination ("Upload to Team NAS"), the default first, for an Upload button's menu.
    /// Choosing one calls `choose` with its ID; pass that to `upload(_:scale:name:to:)`.
    public func destinationMenu(_ choose: @escaping @MainActor @Sendable (UUID) -> Void) -> NSMenu {
        let menu = NSMenu(title: "Upload To")
        let list = destinations.list
        let ordered = list.destinations.filter { list.isDefault($0.id) } + list.destinations.filter { !list.isDefault($0.id) }
        for destination in ordered {
            let id = destination.id
            let item = ActionMenuItem("Upload to \(destination.displayName)", symbol: destination.kind.symbol) { choose(id) }
            if list.isDefault(id) {
                item.toolTip = "The default destination"
            }
            menu.addItem(item)
        }
        if ordered.isEmpty {
            let item = NSMenuItem(title: "No Upload Destinations", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        return menu
    }

    // MARK: Running an upload

    private func run(to destinationID: UUID?, prepare: @escaping @Sendable (UploadService) async throws -> UploadPayload) async -> URL? {
        guard let destination = destinationID.flatMap(destinations.destination) ?? destinations.defaultDestination else {
            report(.noDestination, for: nil)
            return nil
        }
        let panel = UploadProgressPanel(destinationName: destination.displayName, symbol: destination.kind.symbol)
        let service = service
        // Utility rather than background (PLAN §9): the user is waiting for the link.
        let task = Task(priority: .utility) { () throws -> (UploadReceipt, UploadPayload) in
            try await service.checkReady(destination)
            let payload = try await prepare(service)
            do {
                let receipt = try await service.upload(payload, to: destination) { progress in
                    Task { @MainActor in panel.update(progress) }
                }
                await service.discard(payload)
                return (receipt, payload)
            } catch {
                await service.discard(payload)
                throw error
            }
        }
        panel.onCancel = { task.cancel() }
        let presenting = Task { [weak self] in
            try? await Task.sleep(for: Self.panelDelay)
            guard !Task.isCancelled else { return }
            self?.present(panel)
        }
        do {
            let (receipt, payload) = try await task.value
            presenting.cancel()
            learn(receipt, for: destination)
            finish(receipt, payload: payload, destination: destination, panel: panel)
            return receipt.link
        } catch {
            presenting.cancel()
            let failure = UploadError.from(error)
            log.error("upload to \(destination.kind.rawValue, privacy: .public) failed: \(failure.localizedDescription, privacy: .private)")
            report(failure, for: destination, panel: panel)
            return nil
        }
    }

    /// Keeps what the upload found out, such as the Drive folder it made.
    private func learn(_ receipt: UploadReceipt, for destination: UploadDestination) {
        guard let learned = receipt.updatedTarget, var current = destinations.destination(destination.id) else { return }
        current.target = current.target.learning(learned, startedWith: destination.target)
        destinations.update(current)
    }

    private func finish(_ receipt: UploadReceipt, payload: UploadPayload, destination: UploadDestination, panel: UploadProgressPanel) {
        let copies = settings[UploadSettings.copiesLink]
        if copies {
            Pasteboard.copy(destination.linkFormat.text(for: receipt.link, name: payload.name, isImage: payload.isImage))
        }
        if let notice = receipt.notice {
            if !panel.isVisible {
                present(panel)
            }
            panel.showNotice(copies ? "\(notice) The link is copied." : notice)
            return
        }
        panel.close()
        Toast.show(
            copies ? "Uploaded to \(destination.displayName) — link copied" : "Uploaded to \(destination.displayName)",
            symbol: "icloud.and.arrow.up"
        )
    }

    private func report(_ error: UploadError, for destination: UploadDestination?, panel: UploadProgressPanel? = nil) {
        if error.isCancellation {
            panel?.close()
            Toast.show("Upload cancelled", symbol: "xmark.circle")
            return
        }
        let panel = panel ?? UploadProgressPanel(destinationName: destination?.displayName ?? "", symbol: "icloud.and.arrow.up")
        if !panel.isVisible {
            present(panel)
        }
        panel.showFailure(error.localizedDescription)
    }

    private func present(_ panel: UploadProgressPanel) {
        guard !panel.isVisible else { return }
        let offset = panels.filter(\.isVisible).reduce(CGFloat(0)) { $0 + $1.height + 8 }
        panels.append(panel)
        panel.onClose = { [weak self, weak panel] in
            self?.panels.removeAll { $0 === panel }
        }
        panel.show(on: ScreenLocator.screenUnderMouse, offset: offset)
    }

    static func safeName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespaces).isEmpty ? "Oriel" : cleaned
    }
}
