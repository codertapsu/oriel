import AppKit
import SwiftUI

/// The current colour as a swatch; it opens the palette and a custom colour well.
struct ColorButton: View {
    let session: EditorSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(Color(cgColor: session.color.cgColor))
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1))
                .frame(width: 18, height: 18)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Colour")
        .accessibilityLabel("Colour")
        .accessibilityValue(session.color.paletteName ?? "Custom")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColorPalette(session: session)
        }
    }
}

/// The palette swatches and a colour well for anything else.
private struct ColorPalette: View {
    let session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(RGBAColor.palette, id: \.color) { entry in
                    Button {
                        session.setColor(entry.color)
                    } label: {
                        Circle()
                            .fill(Color(cgColor: entry.color.cgColor))
                            .overlay(Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                    .padding(-3)
                                    .opacity(entry.color == session.color ? 1 : 0)
                            )
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.name)
                    .accessibilityAddTraits(entry.color == session.color ? .isSelected : [])
                }
            }
            ColorPicker("Custom colour", selection: customColor, supportsOpacity: false)
        }
        .padding(14)
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(cgColor: session.color.cgColor) },
            set: { newValue in
                if let color = RGBAColor(NSColor(newValue)) {
                    session.setColor(color)
                }
            }
        )
    }
}
