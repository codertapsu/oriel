import SwiftUI

/// The Cloud Translation glossary a project maps to, for Google. Google creates glossaries only from files in Cloud
/// Storage, which Oriel does not write to, so the field names an existing glossary and says how to make one.
struct GlossaryGoogleField: View {
    let glossaries: GlossaryLibraryModel
    let projectID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Google Cloud glossary")
                TextField(
                    "Google Cloud glossary",
                    text: Binding(
                        get: { [glossaries, projectID] in glossaries.project(projectID)?.googleGlossary ?? "" },
                        set: { [glossaries, projectID] in glossaries.setGoogleGlossary($0, for: projectID) }
                    ),
                    prompt: Text("projects/…/locations/us-central1/glossaries/…, or its ID")
                )
                .labelsHidden()
            }
            if isMalformed {
                Label("Enter the glossary as projects/…/locations/…/glossaries/…, or as its ID.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(Self.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let note = """
    Optional. Google providers with a service account key use this glossary instead of the terms above. To make one, \
    export the terms as “CSV for Google Cloud”, put the file in a Cloud Storage bucket and create the glossary in the \
    Google Cloud console.
    """

    /// Checked as if the key's project were known, so only the shape of the name is judged.
    private var isMalformed: Bool {
        let text = glossaries.project(projectID)?.googleGlossary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !text.isEmpty && GoogleTranslateProvider.glossaryResource(text, projectID: "project") == nil
    }
}
