import AppKit

/// The inspector: what the selection is, its sizes, where it is, its dates and what is special about it, with the
/// actions for it; with nothing selected, the folder shown, and for the scanned folder itself, the scan. What APFS and
/// Spotlight know about a single file (space shared with clones, "last opened") is looked up off the main thread.
final class InspectorViewController: NSViewController {
    weak var actions: DiskActions?
    let model: DiskAnalyzerModel
    private let page = StackPage(insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), spacing: 10)
    private var factsTask: Task<Void, Never>?
    /// What was looked up for the file shown: APFS's clone facts and Spotlight's "last opened".
    var facts: (node: Int32, clone: CloneFacts?, lastOpened: Date?)?

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        page.setAccessibilityLabel("Inspector")
        view = page
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    private func render() {
        let content = model.content
        let selection = model.actionableSelection.isEmpty ? model.selection : model.actionableSelection
        _ = model.treeVersion
        guard content == .scan, let tree = model.tree else {
            page.show([PageParts.text("Details of what you select show here.")])
            return
        }
        let shown = selection.filter(tree.contains)
        switch shown.count {
        case 0:
            page.show(model.focus == ScanTree.rootIndex ? scanViews(tree) : itemViews(model.focus, in: tree))
        case 1:
            lookUpFacts(for: shown[0], in: tree)
            page.show(itemViews(shown[0], in: tree))
        default:
            page.show(multipleViews(shown, in: tree))
        }
    }

    /// Looks up what APFS and Spotlight know about a single file, once per selection.
    private func lookUpFacts(for node: Int32, in tree: ScanTree) {
        guard facts?.node != node, tree[node].kind == .file else { return }
        factsTask?.cancel()
        facts = (node, nil, nil)
        let path = model.displayPath(of: node)
        let asksSpotlight = model.settings[DiskSettings.usesSpotlightDates]
        factsTask = Task { [weak self] in
            let found = await Task.detached(priority: .utility) {
                (CloneFacts.of(path), asksSpotlight ? LastOpenedDates.date(of: path) : nil)
            }.value
            guard let self, !Task.isCancelled, facts?.node == node else { return }
            facts = (node, found.0, found.1)
            render()
        }
    }

    // MARK: Several items

    private func multipleViews(_ nodes: [Int32], in tree: ScanTree) -> [NSView] {
        let topmost = model.plan(.trash, nodes: nodes)
        let bytes = topmost?.bytes ?? nodes.reduce(0) { $0 + tree[$1].size }
        let files = nodes.reduce(0) { $0 + Int(tree[$1].fileCount) }
        var views: [NSView] = [
            PageParts.title(DiskFormat.count(nodes.count, "item") + " selected", size: 15),
            PageParts.facts([
                .init("Size", DiskFormat.bytes(bytes)),
                .init("Files", files.formatted()),
                .init("Share of scan", DiskFormat.share(bytes, of: tree.root.size)),
            ]),
        ]
        let refused = nodes.compactMap(model.refusal(for:))
        if let reason = refused.first {
            let which = refused.count == nodes.count ? "these" : "\(refused.count) of these"
            views.append(refusalNote("Oriel won't remove \(which). \(reason)"))
        }
        views.append(ButtonRow([
            ("Reveal in Finder", { [weak self] in self?.model.revealInFinder(nodes) }),
            ("Move to Trash…", { [weak self] in self?.actions?.trash(nodes) }),
        ], primaryFirst: false))
        return views
    }

    func refusalNote(_ text: String) -> NSView {
        let icon = PageParts.icon("lock", size: 11, tint: .secondaryLabelColor)
        let label = PageParts.text(text, size: NSFont.smallSystemFontSize)
        let row = NSStackView(views: [icon, label])
        row.alignment = .firstBaseline
        row.spacing = 5
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }
}
