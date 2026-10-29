import SwiftUI

/// The strip above the canvas: the tools, the colour, the width, the step options while steps are in use, the
/// background, and the smart tools (Smart Redact, Simplify, Smart Move).
struct EditorToolbar: View {
    let session: EditorSession
    let background: BackgroundTool
    let smart: SmartTools?
    @State private var isSimplifyPresented = false
    @State private var isSmartMovePresented = false
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
            if let smart {
                smartTools(smart)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: session.tool)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tools")
    }

    @ViewBuilder private func smartTools(_ smart: SmartTools) -> some View {
        if smart.canReadText {
            SmartToolButton(
                symbol: "eye.slash",
                title: "Smart Redact",
                help: "Smart Redact: hide private details found in the text (⇧⌘R)",
                isPresented: Binding(get: { smart.isRedactPresented }, set: { smart.isRedactPresented = $0 })
            ) {
                SmartRedactPanel(tools: smart)
            }
            SmartToolButton(
                symbol: "text.redaction",
                title: "Simplify",
                help: "Simplify: replace text with bars",
                isPresented: $isSimplifyPresented
            ) {
                SimplifyPanel(tools: smart, isPresented: $isSimplifyPresented)
            }
        }
        SmartToolButton(
            symbol: "wand.and.stars",
            title: "Smart Move",
            help: "Smart Move: lift text and objects so you can move or delete them",
            isPresented: $isSmartMovePresented
        ) {
            SmartMovePanel(tools: smart, isPresented: $isSmartMovePresented)
        }
    }
}
