import SwiftUI

/// The background tool's popover (PLAN §17, social-ready shots): the presets with live previews and the fill on the
/// left; the layout, the card and the shadow on the right, once there is a background.
struct BackgroundPanel: View {
    let tool: BackgroundTool

    private var hasBackground: Bool {
        tool.session.document.background != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                BackgroundPresetGrid(tool: tool)
                if hasBackground {
                    Divider()
                    BackgroundFillSection(tool: tool)
                }
                if let message = tool.message {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .frame(width: 300, alignment: .topLeading)
            if hasBackground {
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    BackgroundLayoutSection(session: tool.session)
                    Divider()
                    BackgroundCardSection(session: tool.session)
                }
                .frame(width: 270, alignment: .topLeading)
            }
        }
        .padding(16)
        .onDisappear { tool.dismissMessage() }
    }
}
