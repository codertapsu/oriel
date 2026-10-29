import SwiftUI

/// Nine buttons in a 3 × 3 grid: where the image sits on a canvas its aspect made larger than the padding.
struct AlignmentPicker: View {
    let selection: CanvasAlignment
    let onSelect: (CanvasAlignment) -> Void

    private let columns = Array(repeating: GridItem(.fixed(18), spacing: 3), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(CanvasAlignment.allCases) { alignment in
                Button {
                    onSelect(alignment)
                } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(alignment == selection ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(width: 18, height: 14)
                        .overlay(
                            Circle()
                                .fill(alignment == selection ? Color.white : Color.secondary.opacity(0.7))
                                .frame(width: 4, height: 4)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(alignment.title)
                .accessibilityLabel(alignment.title)
                .accessibilityAddTraits(alignment == selection ? .isSelected : [])
            }
        }
        .frame(width: 60)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Position")
    }
}
