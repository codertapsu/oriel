import SwiftUI

/// One tile of the background picker: a live preview of the screenshot on that background, or a symbol for the
/// choices that have nothing to preview yet (the desktop picture, an image to choose, a new preset).
struct PresetTile: View {
    let title: String
    var image: CGImage?
    var symbol: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary.opacity(image == nil ? 1 : 0.4))
                if let image {
                    Image(decorative: image, scale: BackgroundPreviews.tileScale)
                        .resizable()
                        .scaledToFit()
                        .frame(width: BackgroundPreviews.tileSize.width, height: BackgroundPreviews.tileSize.height)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(image == nil ? nil : Circle().fill(.regularMaterial))
                }
            }
            .frame(width: BackgroundPreviews.tileSize.width, height: BackgroundPreviews.tileSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
