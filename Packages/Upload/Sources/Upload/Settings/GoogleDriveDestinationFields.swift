import SwiftUI

/// A Google Drive destination's settings, with how to create the OAuth client it signs in through.
struct GoogleDriveDestinationFields: View {
    let model: UploadSettingsModel
    @Binding var destination: UploadDestination
    @Binding var configuration: GoogleDriveConfiguration

    var body: some View {
        TextField("Client ID", text: $configuration.clientID, prompt: Text("…apps.googleusercontent.com"))
        if let problem = configuration.problem {
            Label(problem, systemImage: "exclamationmark.triangle").uploadCaption(.orange)
        }
        if configuration.missingField == nil, configuration.problem == nil {
            UploadCopyableValue(title: "Redirect URI", value: configuration.redirectURI)
        }
        Picker("Access", selection: $configuration.access) {
            ForEach(GoogleDriveConfiguration.Access.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        UploadAccountRow(model: model, destination: destination)
        TextField("Folder", text: $configuration.folderID, prompt: Text("Optional: a folder's ID or link"))
        Text(folderNote).uploadCaption(configuration.foldersNeedFullAccess ? .orange : .secondary)
        Toggle("Anyone with the link can view", isOn: $configuration.sharesPublicly)
        Picker("Link opens", selection: $configuration.linkStyle) {
            ForEach(GoogleDriveConfiguration.LinkStyle.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        UploadSetupSteps(title: "Set up a Google Cloud client once", steps: Self.steps, note: Self.note)
    }

    private var folderNote: String {
        if configuration.foldersNeedFullAccess {
            return "A folder you made yourself needs “\(GoogleDriveConfiguration.Access.everything.title)”; with “"
                + "\(GoogleDriveConfiguration.Access.appFiles.title)”, Oriel can only use folders it made."
        }
        return "Empty: an “\(GoogleDriveDestination.folderName)” folder in My Drive, which Oriel makes with the first upload."
    }

    private static let steps = [
        "In the [Google Cloud console](https://console.cloud.google.com), make a project and enable the Google Drive API for it.",
        "Under Google Auth Platform, set up the consent screen for External users and add yourself as a test user.",
        "Under Clients, create an OAuth client of type iOS with the bundle ID `com.codertapsu.oriel`; paste its client ID "
            + "above and Sign In.",
    ]

    private static let note = """
    While the app is in Testing, Google ends the sign-in after 7 days; publish it (Audience → Publish App) to stay signed in.
    """
}
