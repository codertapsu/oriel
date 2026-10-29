import SwiftUI

/// The frame every smart tool's review panel shares: title, what it does, the review itself, then Cancel and the
/// tool's action.
struct SmartPanelChrome<Content: View>: View {
    let title: String
    let summary: String
    let phase: SmartPhase
    let working: String
    let actionTitle: String
    let canApply: Bool
    let onCancel: () -> Void
    let onApply: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switch phase {
            case .idle, .working:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(working).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityElement(children: .combine)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .ready:
                content()
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle, action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canApply || phase != .ready)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 320)
    }
}
