import SwiftUI

/// A shared folder's settings.
struct SharedFolderDestinationFields: View {
    let model: UploadSettingsModel
    let id: UUID
    @Binding var configuration: SharedFolderConfiguration
    let nameTemplate: String

    var body: some View {
        LabeledContent("Folder") {
            HStack {
                Text(configuration.path.isEmpty ? "None chosen" : (configuration.path as NSString).abbreviatingWithTildeInPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Choose…") { model.chooseFolder(id) }
            }
        }
        UploadLinkTemplateField(
            template: $configuration.publicURLTemplate,
            nameTemplate: nameTemplate,
            fallback: "the file's smb:// address on a server share, or its file:// address"
        )
        Text(Self.note).uploadCaption()
    }

    private static let note = """
    A server share (SMB, AFP, NFS), a NAS, or a synced folder such as iCloud Drive or Dropbox. Oriel finds the folder \
    again after it is renamed or moved. A server share must be connected in Finder when you upload.
    """
}
