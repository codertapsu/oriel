import SwiftUI

/// The public URL template of a destination whose files a web server can serve, with what a link would look like.
struct UploadLinkTemplateField: View {
    @Binding var template: String
    let nameTemplate: String
    /// What is copied without a template, in words.
    let fallback: String

    var body: some View {
        TextField("Public URL", text: $template, prompt: Text("Optional"))
            .textContentType(.URL)
        Text(caption)
            .lineLimit(3)
            .truncationMode(.middle)
            .uploadCaption(UploadLinkTemplate.problem(template) == nil ? .secondary : .orange)
    }

    private var caption: String {
        if let problem = UploadLinkTemplate.problem(template) {
            return problem
        }
        if let preview = UploadSettingsModel.linkPreview(template, nameTemplate: nameTemplate) {
            return "Links look like \(preview)"
        }
        return "For a web server that serves the folder, such as https://files.example.com/{path}, where {path} is the file's "
            + "path in the folder. Without one, Oriel copies \(fallback)."
    }
}
