import SwiftUI

/// The strip above the canvas: the tools, the colour, the width, the step options while steps are in use, and the
/// background.
struct EditorToolbar: View {
    let session: EditorSession
    let background: BackgroundTool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorTool.allCases) { tool in
                ToolButton(tool: tool, isSelected: session.tool == tool) {
                    session.selectTool(tool)
                }
            }
            Divider().frame(height: 22).padding(.horizontal, 6)
            ColorButton(session: session)
            WidthControl(session: session)
            if session.showsStepOptions {
                StepStyleButton(session: session)
            }
            Divider().frame(height: 22).padding(.horizontal, 6)
            BackgroundButton(tool: background)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: session.tool)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tools")
    }
}
