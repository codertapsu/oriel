import SwiftUI

/// The background picker's tiles, each a live preview of the screenshot on that background: the built-in presets,
/// the desktop picture, an image to choose, and the user's saved presets with a tile to save the current one.
struct BackgroundPresetGrid: View {
    let tool: BackgroundTool
    @State private var isNaming = false
    @State private var newName = ""

    private let columns = Array(repeating: GridItem(.fixed(BackgroundPreviews.tileSize.width), spacing: 6), count: 5)

    private var session: EditorSession {
        tool.session
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background").font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(BackgroundPreset.allCases) { preset in
                    PresetTile(
                        title: preset.title,
                        image: tile(for: preset),
                        symbol: preset == .none ? "slash.circle" : nil,
                        isSelected: isCurrent(preset)
                    ) {
                        session.applyBackground(preset)
                    }
                }
                PresetTile(title: "Desktop picture", symbol: "menubar.dock.rectangle", isSelected: usesPicture(from: .desktopPicture)) {
                    Task { await tool.useDesktopPicture() }
                }
                PresetTile(title: "Choose a picture…", symbol: "photo.badge.plus", isSelected: usesPicture(from: .file)) {
                    tool.choosePicture()
                }
            }
            if let library = tool.library {
                Text("My backgrounds").font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(library.presets) { preset in
                        PresetTile(
                            title: preset.name,
                            image: tool.previews.tile(for: session.document, style: preset.style, padding: preset.padding),
                            symbol: preset.picture == nil ? nil : "photo"
                        ) {
                            Task { await tool.apply(preset) }
                        }
                        .contextMenu {
                            Button("Delete “\(preset.name)”", role: .destructive) {
                                tool.deletePreset(preset)
                            }
                        }
                    }
                    PresetTile(title: "Save the current background", symbol: "plus") {
                        newName = ""
                        isNaming = true
                    }
                    .disabled(session.document.background == nil)
                }
            }
        }
        .alert("Save Background", isPresented: $isNaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName
                Task { await tool.saveCurrent(named: name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved backgrounds keep the fill, padding, inset, aspect, corners, shadow and frame.")
        }
    }

    private func tile(for preset: BackgroundPreset) -> CGImage? {
        let current = session.document.background
        let style = preset.style.map { current?.withFill(of: $0) ?? $0 }
        let padding = session.document.canvasPadding?.top ?? BackgroundPreset.defaultPadding(for: session.document.visibleImageRect.size)
        return tool.previews.tile(for: session.document, style: style, padding: padding)
    }

    private func isCurrent(_ preset: BackgroundPreset) -> Bool {
        guard let current = session.document.background else { return preset == .none }
        guard let style = preset.style else { return false }
        return current.withFill(of: style) == current
    }

    private func usesPicture(from source: BackgroundImage.Source) -> Bool {
        guard let background = session.document.background, background.fill == .image else { return false }
        return background.image?.source == source
    }
}
