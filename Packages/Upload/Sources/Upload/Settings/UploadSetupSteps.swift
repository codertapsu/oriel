import SwiftUI

/// Numbered steps for setting up a service, in Markdown so links open and commands read as `code`.
struct UploadSetupSteps: View {
    let title: String
    let steps: [String]
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.semibold)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(index + 1).").monospacedDigit()
                    Text(Self.markdown(step))
                }
            }
            if let note {
                Text(Self.markdown(note)).padding(.top, 2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ??
            AttributedString(text)
    }
}
