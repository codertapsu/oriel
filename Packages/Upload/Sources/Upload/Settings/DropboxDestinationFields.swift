import SwiftUI

/// A Dropbox destination's settings, with how to create the Dropbox app it signs in through.
struct DropboxDestinationFields: View {
    let model: UploadSettingsModel
    @Binding var destination: UploadDestination
    @Binding var configuration: DropboxConfiguration

    var body: some View {
        TextField("App key", text: $configuration.appKey, prompt: Text("From the Dropbox App Console"))
        if let problem = configuration.problem {
            Label(problem, systemImage: "exclamationmark.triangle").uploadCaption(.orange)
        }
        if configuration.missingField == nil {
            UploadCopyableValue(title: "Redirect URI", value: configuration.redirectURI)
        }
        UploadAccountRow(model: model, destination: destination)
        TextField("Folder", text: $configuration.folder, prompt: Text("Optional: the top of the Dropbox"))
        Picker("Link opens", selection: $configuration.linkStyle) {
            ForEach(DropboxConfiguration.LinkStyle.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        UploadSetupSteps(title: "Set up a Dropbox app once", steps: Self.steps, note: Self.note)
    }

    private static let steps = [
        "At [dropbox.com/developers/apps](https://www.dropbox.com/developers/apps), choose Create App, then Scoped access "
            + "and App folder (or Full Dropbox).",
        "On its Permissions tab, tick `files.content.write`, `sharing.write` and `sharing.read`, then Submit.",
        "Copy the App key from its Settings tab into App key above, and Sign In.",
    ]

    private static let note = """
    Oriel signs in through the redirect URI above, which Dropbox allows for every app; if Dropbox calls it unknown, add it \
    under OAuth 2 → Redirect URIs. In an App folder app, the folder is inside Apps → your app's name.
    """
}
