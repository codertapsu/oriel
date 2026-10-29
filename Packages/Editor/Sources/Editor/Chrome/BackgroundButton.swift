import SwiftUI

/// The background tool's button: presets, fill, padding, inset, aspect, corners, frame and shadow, in a popover.
struct BackgroundButton: View {
    let tool: BackgroundTool
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
        .help("Background, padding and aspect")
        .accessibilityLabel("Background")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            BackgroundPanel(tool: tool)
        }
    }
}
