import SwiftUI

/// The background tool: presets, padding, corner radius and shadow, in a popover.
struct BackgroundButton: View {
    let session: EditorSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Background and padding")
        .accessibilityLabel("Background")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            BackgroundPanel(session: session)
        }
    }
}

private struct BackgroundPanel: View {
    let session: EditorSession

    var body: some View {
        let background = session.document.background
        VStack(alignment: .leading, spacing: 12) {
            Text("Background").font(.headline)
            HStack(spacing: 8) {
                ForEach(BackgroundPreset.allCases) { preset in
                    Button {
                        session.applyBackground(preset)
                    } label: {
                        PresetSwatch(preset: preset)
                    }
                    .buttonStyle(.plain)
                    .help(preset.title)
                    .accessibilityLabel(preset.title)
                }
            }
            if let background {
                LabeledContent("Padding") {
                    Slider(
                        value: Binding(get: { session.document.canvasPadding?.top ?? 0 }, set: { session.setPadding($0) }),
                        in: 0 ... 200
                    )
                    .accessibilityLabel("Padding")
                }
                LabeledContent("Corner radius") {
                    Slider(value: Binding(get: { background.cornerRadius }, set: { session.setCornerRadius($0) }), in: 0 ... 48)
                        .accessibilityLabel("Corner radius")
                }
                Toggle("Shadow", isOn: Binding(get: { background.shadow }, set: { session.setShadow($0) }))
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// A small preview of a preset's fill.
private struct PresetSwatch: View {
    let preset: BackgroundPreset

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.secondary.opacity(0.4)))
            .overlay {
                if preset == .none {
                    Image(systemName: "slash.circle").foregroundStyle(.secondary)
                }
            }
            .frame(width: 30, height: 30)
    }

    private var fill: AnyShapeStyle {
        guard let style = preset.style else { return AnyShapeStyle(Color.clear) }
        let colors = style.colors.map { Color(cgColor: $0.cgColor) }
        switch style.fill {
        case .none: return AnyShapeStyle(Color.clear)
        case .solid: return AnyShapeStyle(colors.first ?? .clear)
        case .gradient: return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}
