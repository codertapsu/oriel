import SwiftUI

/// One tool in the tool strip: an SF Symbol with the tool's name as its label and its shortcut in the tooltip.
struct ToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.symbolName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tool.help)
        .accessibilityLabel(tool.title)
        .accessibilityHint("Shortcut \(String(tool.shortcut).uppercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
