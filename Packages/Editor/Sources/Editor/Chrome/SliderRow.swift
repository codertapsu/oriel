import SwiftUI

/// A labelled slider with its value written after it ("24 pt"), for the editor's panels. One grid row: the label,
/// the slider, the value. The slider is continuous (a stepped one draws a tick per step, a dashed line on long
/// ranges); the session rounds what it stores.
struct SliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    /// Formats the value shown after the slider.
    var format: (Double) -> String = { "\(Int($0.rounded())) pt" }

    var body: some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Slider(value: value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(format(value.wrappedValue))
            Text(format(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}
