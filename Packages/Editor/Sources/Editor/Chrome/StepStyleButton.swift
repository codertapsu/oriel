import SwiftUI

/// The numbered-steps options, while the step tool is on or steps are selected: shape, pointer, label style, and
/// where the numbering goes on. They apply to the next step and to the selected ones; size and colour are the
/// toolbar's width and colour.
struct StepStyleButton: View {
    let session: EditorSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: session.stepStyle.shape.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Step style and numbering")
        .accessibilityLabel("Step style")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            StepStylePanel(session: session)
        }
    }
}
