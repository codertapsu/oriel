import SwiftUI

/// Who is signed in to Dropbox or Google Drive, with Sign In and Sign Out, and what the last sign-in said.
struct UploadAccountRow: View {
    let model: UploadSettingsModel
    let destination: UploadDestination

    var body: some View {
        LabeledContent("Account") {
            HStack {
                if model.signIns[destination.id] == .running {
                    ProgressView().controlSize(.small)
                    Text("Waiting for \(destination.kind.title)…").foregroundStyle(.secondary)
                } else if let tokens {
                    Text(tokens.account ?? "Signed in")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Sign Out") { model.signOut(destination.id) }
                } else {
                    Text("Not signed in").foregroundStyle(.secondary)
                    Button("Sign In…") { model.signIn(destination.id) }
                        .disabled(destination.target.missingField != nil || destination.target.problem != nil)
                }
            }
        }
        if let note {
            Label(note, systemImage: "exclamationmark.triangle").uploadCaption(.orange)
        }
    }

    private var tokens: OAuthTokens? {
        model.tokens(destination.id)
    }

    /// The last sign-in's failure, or what about the kept sign-in no longer matches the settings.
    private var note: String? {
        if case let .failed(message) = model.signIns[destination.id] {
            return message
        }
        guard let tokens else { return nil }
        if let clientID = destination.target.oauthClientID, !tokens.belongs(to: clientID) {
            let client = destination.kind == .dropbox ? "app key" : "client ID"
            return "This sign-in belongs to another \(client). Sign out, then sign in again."
        }
        if case let .googleDrive(configuration) = destination.target, !tokens.grants(configuration.access.scope) {
            return "Sign out and in again to give Oriel “\(configuration.access.title)”."
        }
        return nil
    }
}
