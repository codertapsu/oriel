import SwiftUI

/// A WebDAV server's settings.
struct WebDAVDestinationFields: View {
    let model: UploadSettingsModel
    let id: UUID
    @Binding var configuration: WebDAVConfiguration
    let nameTemplate: String

    var body: some View {
        TextField("Server", text: $configuration.serverURL, prompt: Text("Required"))
            .textContentType(.URL)
        TextField("User name", text: $configuration.username, prompt: Text("Optional"))
        UploadSecretField(title: "Password", model: model, id: id, isRequired: !configuration.username.isEmpty)
        if configuration.sendsPasswordInClear {
            Label(
                "Plain http:// sends the password readably. Use https:// unless the server is on your own network.",
                systemImage: "lock.open"
            )
            .uploadCaption(.orange)
        }
        TextField("Folder", text: $configuration.folder, prompt: Text("Optional: the server address itself"))
        UploadLinkTemplateField(
            template: $configuration.publicURLTemplate,
            nameTemplate: nameTemplate,
            fallback: "the file's WebDAV address"
        )
        Text(Self.note).uploadCaption()
    }

    private static let note = """
    The server is a WebDAV address, such as https://cloud.example.com/remote.php/dav/files/you; Nextcloud and ownCloud \
    show it under Files → Settings → WebDAV, and take an app password from your security settings. Folders that are \
    missing are made. The server chooses Basic or Digest sign-in.
    """
}
