import AppKit

/// What the sunburst and the treemap share: the tree they draw, hover with a tip, selection, the keyboard, context
/// menus and VoiceOver. Layouts are computed off the main thread by the subclasses; drawing uses CoreGraphics.
class ChartView: NSView {
    /// Opens a folder (drills in).
    var onOpen: ((Int32) -> Void)?
    var onSelect: (([Int32]) -> Void)?
    var onUp: (() -> Void)?
    /// The context menu for an item, or for the folder shown when nil.
    var menuProvider: ((Int32?) -> NSMenu?)?
    /// The name shown for a node.
    var nameProvider: ((Int32) -> String)?

    private(set) var tree: ScanTree?
    private(set) var root: Int32 = ScanTree.rootIndex
    private(set) var selection: Set<Int32> = []
    private(set) var hovered: ChartHit?
    /// The tip's text for `hovered`, worked out once per item rather than on every move.
    private var hoverText: (title: String, detail: String)?
    let tip = ChartTip()
    private var version = -1
    private var tracking: NSTrackingArea?
    private var elements: [ChartElement] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        addSubview(tip)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isOpaque: Bool {
        false
    }

    /// Shows `root` of `tree`. The layout is computed again only when the tree or the folder changed.
    func show(_ tree: ScanTree, root: Int32, selection: Set<Int32>, version: Int) {
        let changed = version != self.version || root != self.root
        let drilled = root != self.root && self.version == version
        self.tree = tree
        self.root = root
        self.selection = selection
        self.version = version
        if changed {
            hovered = nil
            hoverText = nil
            tip.hide()
            relayout(animated: drilled)
        } else {
            needsDisplay = true
        }
    }

    // MARK: For subclasses

    /// Computes the layout for the current tree, root and bounds, off the main thread, then draws.
    func relayout(animated _: Bool) {}

    /// What is under `point`.
    func hit(at _: CGPoint) -> ChartHit? {
        nil
    }

    /// A click on `hit`; the default selects it.
    func clicked(_ hit: ChartHit, with event: NSEvent) {
        guard hit.node != ScanNode.none, !hit.isCenter else { return }
        select(hit.node, extending: event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift))
    }

    /// The items VoiceOver lists: label, frame and node.
    func accessibilityItems() -> [(label: String, frame: CGRect, node: Int32)] {
        []
    }

    /// Fades to the new layout, unless Reduce Motion is on.
    func transition() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer else { return }
        let fade = CATransition()
        fade.type = .fade
        fade.duration = 0.22
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(fade, forKey: "drill")
    }

    func layoutDidChange() {
        needsDisplay = true
        rebuildAccessibility()
        if let point = window?.mouseLocationOutsideOfEventStream {
            updateHover(at: convert(point, from: nil))
        }
    }

    // MARK: Names and tips

    func name(of node: Int32) -> String {
        if let nameProvider {
            return nameProvider(node)
        }
        guard let tree else { return "" }
        return tree[node].kind == .smallFiles ? DiskFormat.smallFiles(Int(tree[node].fileCount)) : tree.name(of: node)
    }

    /// The tip's lines for `hit`: its name, then its size and share of the folder shown.
    func describe(_ hit: ChartHit) -> (title: String, detail: String) {
        guard let tree else { return ("", "") }
        let whole = tree[root].size
        if hit.isCenter {
            let up = root == ScanTree.rootIndex ? "" : " · click to go up"
            return (name(of: root), DiskFormat.bytes(whole) + up)
        }
        if hit.node == ScanNode.none {
            let bytes = hit.mergedBytes
            return (DiskFormat.count(hit.mergedCount, "smaller item"), "\(DiskFormat.bytes(bytes)) · \(DiskFormat.share(bytes, of: whole))")
        }
        let node = tree[hit.node]
        var detail = "\(DiskFormat.bytes(node.size)) · \(DiskFormat.share(node.size, of: whole))"
        if node.kind.isContainer {
            detail += " · " + DiskFormat.count(Int(node.fileCount), "file")
        }
        return (name(of: hit.node), detail)
    }

    // MARK: Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with _: NSEvent) {
        hovered = nil
        hoverText = nil
        tip.hide()
        needsDisplay = true
    }

    private func updateHover(at point: CGPoint) {
        let hit = bounds.contains(point) ? hit(at: point) : nil
        if hit != hovered {
            hovered = hit
            hoverText = hit.map(describe)
            needsDisplay = true
        }
        guard let hoverText else {
            tip.hide()
            return
        }
        tip.show(title: hoverText.title, detail: hoverText.detail, near: point)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let hit = hit(at: convert(event.locationInWindow, from: nil)) else {
            if !event.modifierFlags.contains(.command) {
                onSelect?([])
            }
            return
        }
        clicked(hit, with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let hit = hit(at: convert(event.locationInWindow, from: nil))
        guard let hit, hit.node != ScanNode.none, !hit.isCenter else { return menuProvider?(nil) }
        if !selection.contains(hit.node) {
            onSelect?([hit.node])
        }
        return menuProvider?(hit.node)
    }

    func select(_ node: Int32, extending: Bool) {
        var next = extending ? selection : []
        if extending, next.contains(node) {
            next.remove(node)
        } else {
            next.insert(node)
        }
        onSelect?(Array(next))
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        guard let tree else { return super.keyDown(with: event) }
        let children = tree.childrenBySize(of: root).filter { !tree[$0].kind.isSynthetic || tree[$0].kind == .smallFiles }
        let current = selection.count == 1 ? selection.first : nil
        switch event.specialKey {
        case .leftArrow?, .rightArrow?:
            guard !children.isEmpty else { return }
            let position = current.flatMap(children.firstIndex(of:)) ?? -1
            let step = event.specialKey == .rightArrow ? 1 : -1
            let next = (position + step + children.count) % children.count
            onSelect?([children[next]])
        case .downArrow?, .carriageReturn?, .enter?:
            if let current, tree[current].kind.isContainer {
                onOpen?(current)
            }
        case .upArrow?:
            onUp?()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: VoiceOver

    override func accessibilityChildren() -> [Any]? {
        elements
    }

    private func rebuildAccessibility() {
        elements = accessibilityItems().map { item in
            ChartElement(label: item.label, frame: item.frame, parent: self) { [weak self] in
                guard let self, let tree else { return }
                if tree[item.node].kind.isContainer {
                    onOpen?(item.node)
                } else {
                    onSelect?([item.node])
                }
            }
        }
    }

    /// "Movies, 120 GB, 34 percent".
    func accessibilityLabel(for node: Int32) -> String {
        guard let tree else { return "" }
        let item = tree[node]
        return "\(name(of: node)), \(DiskFormat.bytes(item.size)), \(DiskFormat.share(item.size, of: tree[root].size))"
    }
}
