import SwiftUI

/// One destination in Settings → Upload: closed, its name, kind and what it still needs; open, all its settings,
/// Test Connection, Make Default and Delete.
struct UploadDestinationRow: View {
    let model: UploadSettingsModel
    @Binding var destination: UploadDestination

    var body: some View {
        DisclosureGroup(isExpanded: expanded) {
            TextField("Name", text: $destination.name, prompt: Text(destination.kind.defaultName))
            fields
            UploadFileFields(destination: $destination)
            actions
            result
        } label: {
            label
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(destination.displayName)
    }

    // MARK: Closed

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: destination.kind.symbol)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(destination.displayName)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if needsAttention {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("This destination isn't ready yet")
                    .accessibilityLabel("Not ready")
            }
            if model.defaultID == destination.id {
                Text("Default")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    /// The kind (unless the name says it already) and where it goes or who is signed in.
    private var subtitle: String {
        let kind = destination.displayName.caseInsensitiveCompare(destination.kind.title) == .orderedSame ? nil : destination.kind.title
        return [kind, detail].compactMap(\.self).joined(separator: " · ")
    }

    private var detail: String {
        if let missing = destination.target.missingField {
            return "Needs \(missing)"
        }
        switch destination.target {
        case let .s3(configuration):
            let host = URL(string: configuration.endpoint)?.host ?? configuration.endpoint
            return "\(host)/\(configuration.bucket)"
        case let .webDAV(configuration):
            return configuration.server?.host ?? configuration.serverURL
        case let .sftp(configuration):
            let user = configuration.effectiveUsername
            return "\(user.isEmpty ? "" : "\(user)@")\(configuration.trimmedHost)"
        case let .sharedFolder(configuration):
            return (configuration.path as NSString).abbreviatingWithTildeInPath
        case .dropbox, .googleDrive:
            return model.tokens(destination.id)?.account ?? (model.hasTokens(destination.id) ? "Signed in" : "Not signed in")
        }
    }

    /// Something is missing or wrong: a setting, the secret key, or the sign-in.
    private var needsAttention: Bool {
        if destination.target.missingField != nil || destination.target.problem != nil {
            return true
        }
        switch destination.target {
        case .s3:
            return !model.hasSecret(destination.id)
        case let .webDAV(configuration):
            return !configuration.username.trimmingCharacters(in: .whitespaces).isEmpty && !model.hasSecret(destination.id)
        case .dropbox, .googleDrive:
            return !model.hasTokens(destination.id)
        case .sftp, .sharedFolder:
            return false
        }
    }

    // MARK: Open

    @ViewBuilder private var fields: some View {
        let id = destination.id
        switch destination.target {
        case .s3:
            S3DestinationFields(model: model, id: id, configuration: s3)
        case .webDAV:
            WebDAVDestinationFields(model: model, id: id, configuration: webDAV, nameTemplate: destination.nameTemplate)
        case .sftp:
            SFTPDestinationFields(model: model, id: id, configuration: sftp, nameTemplate: destination.nameTemplate)
        case .sharedFolder:
            SharedFolderDestinationFields(model: model, id: id, configuration: sharedFolder, nameTemplate: destination.nameTemplate)
        case .dropbox:
            DropboxDestinationFields(model: model, destination: $destination, configuration: dropbox)
        case .googleDrive:
            GoogleDriveDestinationFields(model: model, destination: $destination, configuration: googleDrive)
        }
    }

    private var actions: some View {
        HStack {
            Button("Test Connection") { model.test(destination.id) }
                .disabled(model.tests[destination.id] == .running || destination.target.missingField != nil)
            if model.tests[destination.id] == .running {
                ProgressView().controlSize(.small)
            }
            Spacer()
            if model.defaultID != destination.id {
                Button("Make Default") { model.makeDefault(destination.id) }
            }
            Button("Delete…") { model.pendingRemoval = destination.id }
        }
    }

    /// What the last Test Connection found.
    @ViewBuilder private var result: some View {
        switch model.tests[destination.id] {
        case let .succeeded(message):
            Label(message, systemImage: "checkmark.circle").uploadCaption(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .textSelection(.enabled)
                .uploadCaption(.red)
        case .running, nil:
            EmptyView()
        }
    }

    private var expanded: Binding<Bool> {
        Binding(
            get: { model.expanded.contains(destination.id) },
            set: { isOpen in
                if isOpen {
                    model.expanded.insert(destination.id)
                } else {
                    model.expanded.remove(destination.id)
                }
            }
        )
    }

    // MARK: The kind's settings

    private var s3: Binding<UploadConfiguration> {
        Binding(
            get: {
                if case let .s3(value) = destination.target {
                    value
                } else {
                    UploadConfiguration()
                }
            },
            set: { destination.target = .s3($0) }
        )
    }

    private var webDAV: Binding<WebDAVConfiguration> {
        Binding(
            get: {
                if case let .webDAV(value) = destination.target {
                    value
                } else {
                    WebDAVConfiguration()
                }
            },
            set: { destination.target = .webDAV($0) }
        )
    }

    private var sftp: Binding<SFTPConfiguration> {
        Binding(
            get: {
                if case let .sftp(value) = destination.target {
                    value
                } else {
                    SFTPConfiguration()
                }
            },
            set: { destination.target = .sftp($0) }
        )
    }

    private var sharedFolder: Binding<SharedFolderConfiguration> {
        Binding(
            get: {
                if case let .sharedFolder(value) = destination.target {
                    value
                } else {
                    SharedFolderConfiguration()
                }
            },
            set: { destination.target = .sharedFolder($0) }
        )
    }

    private var dropbox: Binding<DropboxConfiguration> {
        Binding(
            get: {
                if case let .dropbox(value) = destination.target {
                    value
                } else {
                    DropboxConfiguration()
                }
            },
            set: { destination.target = .dropbox($0) }
        )
    }

    private var googleDrive: Binding<GoogleDriveConfiguration> {
        Binding(
            get: {
                if case let .googleDrive(value) = destination.target {
                    value
                } else {
                    GoogleDriveConfiguration()
                }
            },
            set: { destination.target = .googleDrive($0) }
        )
    }
}
