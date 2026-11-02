import OrielCore
import SharedUI
import SwiftUI

/// The background tool's button: presets, fill, padding, inset, aspect, corners, frame and shadow, in a popover.
struct BackgroundButton: View {
    let tool: BackgroundTool
    @State private var isPresented = false

    var body: some View {
        Button {
            if isPresented || ProAccess.shared.check(.backgrounds) {
                isPresented.toggle()
            }
        } label: {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Background, padding and aspect")
        .accessibilityLabel("Background")
        .overlay(alignment: .topTrailing) { ProBadge(.backgrounds).scaleEffect(0.7).offset(x: 8, y: -6) }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            BackgroundPanel(tool: tool)
        }
    }
}
