import SwiftUI

extension View {
    /// The small explanatory text under a setting: wrapped, and aligned with the labels rather than centred in its row.
    func uploadCaption(_ color: Color = .secondary) -> some View {
        font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
