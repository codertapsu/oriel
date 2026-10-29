import AppKit

/// The sunburst: the folder shown in the middle, its contents in the first ring, theirs in the next, each with an angle
/// proportional to its size. A click on a folder goes into it; a click on the center goes up. The layout is computed
/// off the main thread; the paths are built once per layout and size, then reused for every redraw.
final class SunburstView: ChartView {
    private var segments: [SunburstLayout.Segment] = []
    private var paths: [CGPath] = []
    private var pathsSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>?
    private let options = SunburstLayout.Options()

    override func relayout(animated: Bool) {
        layoutTask?.cancel()
        guard let tree else {
            segments = []
            paths = []
            layoutDidChange()
            return
        }
        let root = root
        let options = options
        layoutTask = Task { [weak self] in
            let segments = await Task.detached(priority: .userInitiated) {
                SunburstLayout.segments(in: tree, root: root, options: options)
            }.value
            guard let self, !Task.isCancelled, self.root == root else { return }
            if animated {
                transition()
            }
            self.segments = segments
            paths = []
            layoutDidChange()
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        paths = []
        layoutDidChange()
    }

    private var rings: SunburstLayout.Rings {
        SunburstLayout.Rings(bounds: bounds, rings: options.rings)
    }

    private func buildPathsIfNeeded() {
        guard paths.count != segments.count || pathsSize != bounds.size else { return }
        let rings = rings
        paths = segments.map { Self.path(for: $0, rings: rings) }
        pathsSize = bounds.size
    }

    /// An annular sector. Angles run clockwise from twelve o'clock; in a flipped view that is CoreGraphics' angle
    /// minus a quarter turn, increasing.
    private static func path(for segment: SunburstLayout.Segment, rings: SunburstLayout.Rings) -> CGPath {
        let path = CGMutablePath()
        let start = segment.start - .pi / 2
        let end = segment.end - .pi / 2
        path.addArc(center: rings.center, radius: rings.outer(segment.depth), startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: rings.center, radius: rings.inner(segment.depth), startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    // MARK: Drawing

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let tree else { return }
        buildPathsIfNeeded()
        for (segment, path) in zip(segments, paths) {
            let kind = segment.node == ScanNode.none ? nil : tree[segment.node].kind
            context.addPath(path)
            let fill = ChartPalette.fill(branch: segment.branch, depth: segment.depth, sibling: segment.sibling, kind: kind)
            context.setFillColor(fill.cgColor)
            context.fillPath()
        }
        context.setStrokeColor(ChartPalette.separator.cgColor)
        context.setLineWidth(1)
        for path in paths {
            context.addPath(path)
        }
        context.strokePath()
        drawHighlights(in: context)
        drawCenter(in: context, tree: tree)
    }

    private func drawHighlights(in context: CGContext) {
        if let hovered, !hovered.isCenter, let index = segmentIndex(for: hovered), index < paths.count {
            context.addPath(paths[index])
            context.setFillColor(ChartPalette.hoverOverlay.cgColor)
            context.fillPath()
        }
        guard !selection.isEmpty else { return }
        context.setStrokeColor(ChartPalette.selectionStroke.cgColor)
        context.setLineWidth(2.5)
        for (segment, path) in zip(segments, paths) where selection.contains(segment.node) {
            context.addPath(path)
        }
        context.strokePath()
    }

    private func drawCenter(in context: CGContext, tree: ScanTree) {
        let rings = rings
        let radius = rings.centerRadius - 2
        guard radius > 8 else { return }
        let disc = CGRect(x: rings.center.x - radius, y: rings.center.y - radius, width: radius * 2, height: radius * 2)
        context.addEllipse(in: disc)
        let hoveringCenter = hovered?.isCenter == true && root != ScanTree.rootIndex
        context.setFillColor((hoveringCenter ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18) : .controlBackgroundColor)
            .cgColor)
        context.fillPath()
        context.addEllipse(in: disc)
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1)
        context.strokePath()
        let width = radius * 1.6
        let title = NSAttributedString(string: name(of: root), attributes: [
            .font: NSFont.systemFont(ofSize: radius > 50 ? 13 : 11, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: Self.centered,
        ])
        let size = NSAttributedString(string: DiskFormat.bytes(tree[root].size), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: radius > 50 ? 12 : 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: Self.centered,
        ])
        let titleHeight = min(title.boundingRect(with: CGSize(width: width, height: 60), options: [.usesLineFragmentOrigin]).height, 34)
        let top = rings.center.y - (titleHeight + 16) / 2
        title.draw(
            with: CGRect(x: rings.center.x - width / 2, y: top, width: width, height: titleHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
        size.draw(
            with: CGRect(x: rings.center.x - width / 2, y: top + titleHeight + 1, width: width, height: 16),
            options: [.usesLineFragmentOrigin]
        )
        if root != ScanTree.rootIndex, radius > 40 {
            let arrow = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: nil)
            arrow?.draw(
                in: CGRect(x: rings.center.x - 5, y: top - 14, width: 10, height: 7),
                from: .zero,
                operation: .sourceOver,
                fraction: 0.5,
                respectFlipped: true,
                hints: nil
            )
        }
    }

    private static let centered: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        return style
    }()

    // MARK: Hits

    private func segmentIndex(for hit: ChartHit) -> Int? {
        segments.firstIndex { $0.node == hit.node && $0.parent == (hit.node == ScanNode.none ? hit.parent : $0.parent) }
    }

    override func hit(at point: CGPoint) -> ChartHit? {
        guard let tree, let location = rings.locate(point, flipped: true) else { return nil }
        if location.depth == 0 {
            return ChartHit(node: root, parent: root, isCenter: true)
        }
        guard let index = segments.firstIndex(where: {
            $0.depth == location.depth && location.angle >= $0.start && location.angle < $0.end
        }) else { return nil }
        let segment = segments[index]
        let parent = segment.node == ScanNode.none ? segment.parent : tree[segment.node].parent
        buildPathsIfNeeded()
        let frame = index < paths.count ? paths[index].boundingBoxOfPath : .zero
        return ChartHit(
            node: segment.node,
            parent: parent,
            mergedCount: segment.mergedCount,
            mergedBytes: segment.mergedBytes,
            frame: frame
        )
    }

    override func clicked(_ hit: ChartHit, with event: NSEvent) {
        if hit.isCenter {
            onUp?()
            return
        }
        guard let tree, hit.node != ScanNode.none else { return }
        let extending = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift)
        let node = tree[hit.node]
        if !extending, node.kind.isContainer, node.firstChild != ScanNode.none {
            onOpen?(hit.node)
        } else {
            select(hit.node, extending: extending)
        }
    }

    override func accessibilityItems() -> [(label: String, frame: CGRect, node: Int32)] {
        buildPathsIfNeeded()
        return zip(segments, paths).compactMap { segment, path in
            guard segment.depth == 1, segment.node != ScanNode.none else { return nil }
            return (accessibilityLabel(for: segment.node), path.boundingBoxOfPath, segment.node)
        }
    }

    override func accessibilityLabel() -> String? {
        "Sunburst of \(name(of: root))"
    }
}
