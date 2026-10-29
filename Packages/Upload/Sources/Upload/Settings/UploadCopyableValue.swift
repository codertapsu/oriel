import SharedUI
import SwiftUI

/// A value to paste somewhere else, such as a redirect URI for a developer console: monospaced, selectable, with Copy.
struct UploadCopyableValue: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Button("Copy") { Pasteboard.copy(value) }
                    .accessibilityLabel("Copy \(title)")
            }
        }
    }
}
