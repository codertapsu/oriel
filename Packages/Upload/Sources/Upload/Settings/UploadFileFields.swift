import SwiftUI

/// What every destination has: the uploaded file's name template, how the link is copied, and metadata removal.
struct UploadFileFields: View {
    @Binding var destination: UploadDestination

    var body: some View {
        TextField("File name", text: $destination.nameTemplate, prompt: Text(destination.kind.defaultNameTemplate))
        Text(verbatim: "\(UploadNameTemplate.tokens.joined(separator: " ")) · / makes a folder · for example “\(preview)”")
            .lineLimit(2)
            .truncationMode(.middle)
            .uploadCaption()
        if let warning {
            Label(warning, systemImage: "exclamationmark.triangle").uploadCaption(.orange)
        }
        Picker("Copy the link as", selection: $destination.linkFormat) {
            ForEach(UploadLinkFormat.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        Toggle("Remove metadata from image files", isOn: $destination.stripsMetadata)
            .help("Camera, location and editing history; captures never carry any")
    }

    private var preview: String {
        UploadSettingsModel.namePreview(destination.nameTemplate.isEmpty ? destination.kind.defaultNameTemplate : destination.nameTemplate)
    }

    /// Where the link is the file's own address, a name without `{random}` can be guessed, and on S3 and SFTP a name
    /// that repeats replaces the earlier file.
    private var warning: String? {
        let template = destination.nameTemplate
        let kind = destination.kind
        if [.s3, .sftp].contains(kind), !UploadNameTemplate.namesAreUnique(template) {
            return "Without {random} or {time}, an upload replaces an earlier one with the same name."
        }
        if !kind.usesOAuth, !UploadNameTemplate.isUnguessable(template) {
            return "Without {random}, people who have one link can guess others."
        }
        return nil
    }
}
