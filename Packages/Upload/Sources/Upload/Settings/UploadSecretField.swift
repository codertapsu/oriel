import SwiftUI

/// A password or secret key: typed into a secure field and saved to the Keychain, never shown again. The prompt says
/// whether one is saved.
struct UploadSecretField: View {
    let title: String
    let model: UploadSettingsModel
    let id: UUID
    var isRequired = true

    var body: some View {
        LabeledContent(title) {
            HStack {
                SecureField(title, text: draft, prompt: Text(prompt))
                    .labelsHidden()
                    .onSubmit { model.saveSecret(id) }
                Button("Save") { model.saveSecret(id) }
                    .disabled((model.secretDrafts[id] ?? "").isEmpty)
                if model.hasSecret(id) {
                    Button("Remove") { model.removeSecret(id) }
                }
            }
        }
        if let message = model.secretMessages[id] {
            Text(message).uploadCaption()
        }
    }

    private var prompt: String {
        if model.hasSecret(id) {
            return "Saved in the keychain"
        }
        return isRequired ? "Required" : "Optional"
    }

    private var draft: Binding<String> {
        Binding(get: { model.secretDrafts[id] ?? "" }, set: { model.secretDrafts[id] = $0 })
    }
}
