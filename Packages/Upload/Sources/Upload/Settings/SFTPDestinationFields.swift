import SwiftUI

/// An SSH server's settings, with how to set up a key, since Oriel never takes a password.
struct SFTPDestinationFields: View {
    let model: UploadSettingsModel
    let id: UUID
    @Binding var configuration: SFTPConfiguration
    let nameTemplate: String

    var body: some View {
        TextField("Host", text: $configuration.host, prompt: Text("nas.local, or a Host from ~/.ssh/config"))
        TextField("Port", value: $configuration.port, format: .number.grouping(.never), prompt: Text(verbatim: "22"))
        TextField("User name", text: $configuration.username, prompt: Text("Optional: from ~/.ssh/config, or yours"))
        TextField("Folder", text: $configuration.remoteFolder, prompt: Text("Optional: your login folder"))
        LabeledContent("Key file") {
            HStack {
                Text(configuration.identityFile.isEmpty ? "ssh's own keys and agent" : configuration.identityFile)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Choose…") { model.chooseKeyFile(id) }
                if !configuration.identityFile.isEmpty {
                    Button("Clear") { configuration.identityFile = "" }
                }
            }
        }
        if let problem = configuration.problem {
            Label(problem, systemImage: "exclamationmark.triangle").uploadCaption(.orange)
        }
        UploadLinkTemplateField(
            template: $configuration.publicURLTemplate,
            nameTemplate: nameTemplate,
            fallback: "the file's sftp:// address"
        )
        UploadSetupSteps(title: "Sign-in uses your SSH key, never a password", steps: Self.steps, note: Self.note)
    }

    private static let steps = [
        "No key yet? In Terminal: `ssh-keygen -t ed25519`",
        "Put it on the server: `ssh-copy-id you@host`",
        "Connect once with `ssh you@host` and accept the server's key, so it is in `~/.ssh/known_hosts`.",
    ]

    private static let note = """
    Oriel connects only to servers in `known_hosts`. A key with a passphrase works once it is in the agent: \
    `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`, with `UseKeychain yes` in `~/.ssh/config`.
    """
}
