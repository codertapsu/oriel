import OrielCore
import SwiftUI

/// The folders scans skip: paths, added with a folder picker, and folder names skipped wherever they are.
struct ExclusionsEditor: View {
    let model: DiskSettingsModel
    @Binding var entries: [String]
    @State private var selection = Set<String>()
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            List(entries, id: \.self, selection: $selection) { entry in
                Label(entry, systemImage: entry.hasPrefix("/") || entry.hasPrefix("~") ? "folder" : "textformat")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minHeight: 90, maxHeight: 150)
            .overlay {
                if entries.isEmpty {
                    Text("Nothing is excluded.").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Button("Add Folder…") { model.chooseExclusion() }
                Button("Remove") {
                    model.removeExclusions(selection)
                    selection = []
                }
                .disabled(selection.isEmpty)
                Spacer()
                TextField("Folder name", text: $name, prompt: Text("Folder name, such as node_modules"))
                    .labelsHidden()
                    .frame(maxWidth: 230)
                    .onSubmit(addName)
                Button("Add Name", action: addName)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || name.contains("/"))
            }
        }
    }

    private func addName() {
        model.addExclusion(named: name)
        name = ""
    }
}
