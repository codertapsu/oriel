import SwiftUI

/// The one width slider: stroke width, and for other kinds what it maps to (text size, step size, blur and
/// pixel strength; see `ToolStyle`).
struct WidthControl: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lineweight")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: width, in: Double(ToolStyle.widthRange.lowerBound) ... Double(ToolStyle.widthRange.upperBound), step: 1)
                .controlSize(.small)
                .frame(width: 96)
                .accessibilityLabel("Stroke width")
                .accessibilityValue("\(Int(session.strokeWidth)) points")
            Text("\(Int(session.strokeWidth))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .help("Width: stroke, text size, step size, blur strength")
    }

    private var width: Binding<Double> {
        Binding(get: { Double(session.strokeWidth) }, set: { session.setStrokeWidth(CGFloat($0)) })
    }
}
