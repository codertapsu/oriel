import AppKit

/// The treemap: the folder shown as a rectangle cut into tiles with areas proportional to their size, folders opened
/// up as deep as there is room, with their name on a strip at the top. A click selects; a double click goes into a
/// folder. The squarified layout is computed off the main thread, again when the view is resized.
final class TreemapView: ChartView {
    private var tiles: [TreemapLayout.Tile] = []
    /// The folders whose contents are drawn inside them, so their name goes on a strip.
    private var openedFolders = Set<Int32>()
    private var layoutSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>?
    private let options = TreemapLayout.Options()

    override func relayout(animated: Bool) {
        layoutTask?.cancel()
        guard let tree, bounds.width > 8, bounds.height > 8 else {
            tiles = []
            layoutDidChange()
            return
        }
        let root = root
        let bounds = bounds.insetBy(dx: 1, dy: 1)
        let options = options
        layoutTask = Task { [weak self] in
            let tiles = await Task.detached(priority: .userInitiated) {
                TreemapLayout.tiles(in: tree, root: root, bounds: bounds, options: options)
            }.value
            guard let self, !Task.isCancelled, self.root == root else { return }
            if animated {
                transition()
            }
            self.tiles = tiles
            openedFolders = Set(tiles.map(\.parent))
            layoutSize = bounds.size
            layoutDidChange()
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayout(animated: false)
    }

    // MARK: Drawing

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let tree else { return }
        for tile in tiles {
            let kind = tile.node == ScanNode.none ? nil : tree[tile.node].kind
            let fill = ChartPalette.fill(branch: tile.branch, depth: tile.depth, sibling: tile.sibling, kind: kind)
            context.setFillColor(fill.cgColor)
            context.fill(tile.rect)
            context.setStrokeColor(ChartPalette.separator.cgColor)
            context.setLineWidth(1)
            context.stroke(tile.rect.insetBy(dx: 0.5, dy: 0.5))
            drawLabel(for: tile, fill: fill, tree: tree)
        }
        if let hovered, let tile = tile(for: hovered) {
            context.setFillColor(ChartPalette.hoverOverlay.cgColor)
            context.fill(tile.rect)
        }
        guard !selection.isEmpty else { return }
        context.setStrokeColor(ChartPalette.selectionStroke.cgColor)
        context.setLineWidth(2.5)
        for tile in tiles where selection.contains(tile.node) {
            context.stroke(tile.rect.insetBy(dx: 1.25, dy: 1.25))
        }
    }

    /// The name of a folder on its strip; the name and size of anything else big enough to hold them.
    /// An opened folder's name and size on its strip, the size dropped when there is no room for both; the name and size
    /// of anything else, on two lines when the tile is tall enough.
    private func drawLabel(for tile: TreemapLayout.Tile, fill: NSColor, tree: ScanTree) {
        let rect = tile.rect.insetBy(dx: 4, dy: 2)
        guard rect.width > 34, rect.height > 11 else { return }
        let opened = tile.isContainer && openedFolders.contains(tile.node)
        let name = tile.node == ScanNode.none ? DiskFormat.count(tile.mergedCount, "smaller item") : name(of: tile.node)
        let bytes = tile.node == ScanNode.none ? tile.mergedBytes : tree[tile.node].size
        let color = ChartPalette.text(on: fill)
        let title = NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: opened ? .semibold : .regular),
            .foregroundColor: color, .paragraphStyle: Self.truncating,
        ])
        let size = NSAttributedString(string: DiskFormat.bytes(bytes), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular), .foregroundColor: color.withAlphaComponent(0.8),
        ])
        if opened || rect.height < 28 {
            let sizeWidth = ceil(size.size().width)
            let showsSize = rect.width > sizeWidth + 44
            let nameWidth = rect.width - (showsSize ? sizeWidth + 6 : 0)
            title.draw(with: CGRect(x: rect.minX, y: rect.minY, width: nameWidth, height: 14), options: [.usesLineFragmentOrigin])
            if showsSize {
                size.draw(at: CGPoint(x: rect.maxX - sizeWidth, y: rect.minY + 1))
            }
            return
        }
        title.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 14), options: [.usesLineFragmentOrigin])
        size.draw(with: CGRect(x: rect.minX, y: rect.minY + 14, width: rect.width, height: 13), options: [.usesLineFragmentOrigin])
    }

    private static let truncating: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    // MARK: Hits

    private func tile(for hit: ChartHit) -> TreemapLayout.Tile? {
        tiles.first { $0.node == hit.node && $0.parent == hit.parent }
    }

    override func hit(at point: CGPoint) -> ChartHit? {
        guard let tile = TreemapLayout.tile(at: point, in: tiles) else { return nil }
        return ChartHit(
            node: tile.node,
            parent: tile.parent,
            mergedCount: tile.mergedCount,
            mergedBytes: tile.mergedBytes,
            frame: tile.rect
        )
    }

    override func clicked(_ hit: ChartHit, with event: NSEvent) {
        guard let tree, hit.node != ScanNode.none else { return }
        if event.clickCount == 2, tree[hit.node].kind.isContainer, tree[hit.node].firstChild != ScanNode.none {
            onOpen?(hit.node)
            return
        }
        select(hit.node, extending: event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift))
    }

    override func accessibilityItems() -> [(label: String, frame: CGRect, node: Int32)] {
        tiles.compactMap { tile in
            guard tile.depth == 1, tile.node != ScanNode.none else { return nil }
            return (accessibilityLabel(for: tile.node), tile.rect, tile.node)
        }
    }

    override func accessibilityLabel() -> String? {
        "Treemap of \(name(of: root))"
    }
}
