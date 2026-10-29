import CoreGraphics
import Foundation

/// Live previews for the background picker: the current screenshot, annotations and crop included, on each
/// background, rendered small. The screenshot is rendered once at preview size and reused for every tile until the
/// annotations or the crop change, and each tile is cached by everything it shows.
final class BackgroundPreviews {
    /// The tiles' size in points, and pixels per point (sharp on Retina).
    static let tileSize = CGSize(width: 54, height: 36)
    static let tileScale: CGFloat = 2

    private struct Source {
        let baseID: UUID
        let crop: CGRect?
        let items: [AnnotationItem]
        let thumbnail: ImageRef
    }

    private struct TileKey: Hashable {
        let style: BackgroundStyle?
        let padding: CGFloat
    }

    private let effects = EffectCache(pixelBudget: 2_000_000)
    private var source: Source?
    private var tiles: [TileKey: CGImage] = [:]

    /// `document` on `style` with `padding` around it, fitted into a tile. Nil `style`: the screenshot alone.
    func tile(for document: EditorDocument, style: BackgroundStyle?, padding: CGFloat) -> CGImage? {
        guard let thumbnail = thumbnail(of: document) else { return nil }
        let key = TileKey(style: style, padding: style == nil ? 0 : padding)
        if let cached = tiles[key] {
            return cached
        }
        let preview = EditorDocument(
            base: thumbnail,
            canvasPadding: style == nil ? nil : Padding(all: padding),
            background: style
        )
        let canvas = CanvasLayout(document: preview).canvasSize
        guard canvas.width > 0, canvas.height > 0 else { return nil }
        let fit = min(Self.tileSize.width / canvas.width, Self.tileSize.height / canvas.height) * Self.tileScale
        guard let image = EditorRenderer.makeImage(preview, scale: fit, effects: effects) else { return nil }
        if tiles.count > 64 {
            tiles.removeAll()
        }
        tiles[key] = image
        return image
    }

    /// The visible screenshot with its annotations, at about the resolution a tile needs, with the point size of
    /// the original, so padding and radii keep their proportions.
    private func thumbnail(of document: EditorDocument) -> ImageRef? {
        if let source, source.baseID == document.base.id, source.crop == document.crop, source.items == document.items {
            return source.thumbnail
        }
        var plain = document
        plain.background = nil
        plain.canvasPadding = nil
        let size = document.visibleImageRect.size
        guard size.width > 0, size.height > 0 else { return nil }
        // At least a tenth, the smallest scale an ImageRef keeps, so the thumbnail's point size is the original's.
        let wanted = max(Self.tileSize.width, Self.tileSize.height) * Self.tileScale * 2 / max(size.width, size.height)
        let scale = min(1, max(0.1, wanted))
        guard let image = EditorRenderer.makeImage(plain, scale: scale, effects: effects) else { return nil }
        let thumbnail = ImageRef(image: image, scale: CGFloat(image.width) / size.width)
        source = Source(baseID: document.base.id, crop: document.crop, items: document.items, thumbnail: thumbnail)
        tiles.removeAll()
        return thumbnail
    }
}
