import CoreGraphics
import Foundation
import Observation
import OrielCore
import SharedUI

/// The user's saved backgrounds. The list lives in the settings; the pictures of presets made with a chosen image
/// live as PNGs in `directory` (Application Support/Oriel/Editor/Backgrounds), written and read off the main thread.
@Observable
final class BackgroundLibrary {
    private(set) var presets: [SavedBackground]
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored let directory: URL
    @ObservationIgnored private let log = Log.logger("editor")

    init(
        settings: SettingsStore,
        directory: URL = AppPaths.applicationSupport.appending(path: "Editor/Backgrounds", directoryHint: .isDirectory)
    ) {
        self.settings = settings
        self.directory = directory
        presets = settings[EditorSettings.savedBackgrounds]
    }

    /// Saves `style` with `padding` under `name` (blank names become "My Background"), newest last.
    func save(name: String, style: BackgroundStyle, padding: CGFloat) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID()
        var picture: SavedBackground.Picture?
        if let image = style.image, style.fill == .image {
            switch image.source {
            case .desktopPicture:
                picture = .desktopPicture(blur: image.blur)
            case .file:
                let fileName = "\(id.uuidString.lowercased()).png"
                let url = directory.appending(path: fileName)
                let pixels = image.asset.image
                let written = await Task.detached(priority: .utility) { () -> Bool in
                    guard let data = ImageFile.data(for: pixels, format: .png) else { return false }
                    do {
                        try AppPaths.ensureDirectory(url.deletingLastPathComponent())
                        try data.write(to: url, options: .atomic)
                        return true
                    } catch {
                        return false
                    }
                }.value
                if written {
                    picture = .file(name: fileName, blur: image.blur)
                } else {
                    log.error("A saved background's picture could not be written")
                }
            }
        }
        var style = style
        if picture == nil, style.fill == .image {
            // Without its picture the preset keeps the rest and falls back to a plain fill.
            style.fill = .solid
            style.colors = style.colors.isEmpty ? [BackgroundPainter.placeholder] : style.colors
        }
        let preset = SavedBackground(
            id: id,
            name: trimmed.isEmpty ? "My Background" : trimmed,
            style: style,
            padding: padding,
            picture: picture
        )
        presets.append(preset)
        settings[EditorSettings.savedBackgrounds] = presets
    }

    func delete(_ id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        presets.removeAll { $0.id == id }
        settings[EditorSettings.savedBackgrounds] = presets
        if case let .file(name, _) = preset.picture {
            let url = directory.appending(path: name)
            Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// The style a preset applies, with its picture: the saved file, or the current desktop picture from
    /// `desktopPicture`. Nil when the picture is gone; the caller says so.
    func style(for preset: SavedBackground, desktopPicture: () async -> CGImage?) async -> BackgroundStyle? {
        var style = preset.style
        switch preset.picture {
        case nil:
            return style
        case let .desktopPicture(blur):
            guard let image = await desktopPicture() else { return nil }
            style.image = BackgroundImage(asset: ImageAsset(image: image), source: .desktopPicture, blur: blur)
        case let .file(name, blur):
            let url = directory.appending(path: name)
            guard let image = await Task.detached(priority: .userInitiated, operation: { PictureLoader.load(url) }).value else {
                return nil
            }
            style.image = BackgroundImage(asset: ImageAsset(image: image), source: .file, blur: blur)
        }
        style.fill = .image
        return style
    }
}
