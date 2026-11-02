import OrielCore
import SharedUI
import SwiftUI

/// Settings → Upload (PLAN §7.8, §17): the destinations (S3-compatible storage, WebDAV, SFTP, a shared folder, Dropbox
/// and Google Drive), each with its settings, secrets, name template, link format and Test Connection, and the one
/// Upload in Quick Access and the editor sends to.
public struct UploadSettingsView: View {
    private let settings: SettingsStore
    private let model: UploadSettingsModel

    public init(settings: SettingsStore, keychain _: KeychainStore, coordinator: UploadCoordinator) {
        self.settings = settings
        model = coordinator.settingsModel
    }

    public var body: some View {
        Form {
            uploads
            destinations
        }
        .formStyle(.grouped)
        .confirmationDialog(removalTitle, isPresented: removalShown, presenting: model.pendingRemoval) { id in
            Button("Delete Destination", role: .destructive) { model.remove(id) }
        } message: { id in
            Text(removalMessage(id))
        }
    }

    private var uploads: some View {
        Section("Upload") {
            if model.destinations.isEmpty {
                Text("Add a destination below. Upload in Quick Access and the editor then sends there and copies the link.")
                    .uploadCaption()
            } else {
                Picker("Upload to", selection: model.defaultSelection) {
                    ForEach(model.destinations) { destination in
                        Label(destination.displayName, systemImage: destination.kind.symbol).tag(Optional(destination.id))
                    }
                }
            }
            Toggle("Copy the link after uploading", isOn: settings.binding(UploadSettings.copiesLink))
        }
    }

    private var destinations: some View {
        Section {
            ForEach(model.destinations) { destination in
                UploadDestinationRow(model: model, destination: model.binding(for: destination.id))
            }
            if model.destinations.isEmpty {
                ForEach(UploadDestinationKind.available) { kind in
                    Button { model.add(kind) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.title).foregroundStyle(.primary)
                                Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(kind.title)")
                    .accessibilityHint(kind.summary)
                }
            }
        } header: {
            HStack {
                Text("Destinations")
                ProBadge(.upload)
                Spacer()
                Menu("Add Destination") {
                    ForEach(UploadDestinationKind.available) { kind in
                        Button { model.add(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
                    }
                }
                .fixedSize()
            }
        } footer: {
            Text("Passwords, secret keys and sign-ins stay in your login keychain, never in settings files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var removalShown: Binding<Bool> {
        Binding(get: { model.pendingRemoval != nil }, set: {
            if !$0 {
                model.pendingRemoval = nil
            }
        })
    }

    private var removalTitle: String {
        let name = model.pendingRemoval.flatMap { id in model.destinations.first { $0.id == id } }?.displayName ?? "this destination"
        return "Delete “\(name)”?"
    }

    private func removalMessage(_ id: UUID) -> String {
        guard let destination = model.destinations.first(where: { $0.id == id }) else { return "" }
        let uploaded = "Files already uploaded stay where they are."
        return switch destination.kind {
        case .dropbox, .googleDrive: "Oriel signs out of \(destination.kind.title) and forgets its settings. \(uploaded)"
        case .s3, .webDAV:
            "Oriel forgets its settings and removes its \(UploadSecret.secret(for: destination.kind)?.title ?? "secret") from the "
                + "keychain. \(uploaded)"
        case .sftp, .sharedFolder: "Oriel forgets its settings. \(uploaded)"
        }
    }
}
