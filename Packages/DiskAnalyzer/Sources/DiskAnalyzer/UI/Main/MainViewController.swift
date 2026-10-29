import AppKit

/// The main area: breadcrumbs and the view switcher above, notes that need attention, the view itself, and a status
/// line below. Each view is made the first time it is shown and kept while the window is open.
final class MainViewController: NSViewController {
    weak var actions: DiskActions? {
        didSet {
            for controller in controllers.values {
                controller.actions = actions
            }
        }
    }

    let model: DiskAnalyzerModel
    private let pathControl = NSPathControl()
    private let switcher = NSSegmentedControl()
    private let header = NSView()
    let bannerStack = NSStackView()
    private let container = NSView()
    let statusLine = NSTextField(labelWithString: "")
    private var controllers: [String: any DiskContentController] = [:]
    private var currentKey: String?
    var shownBannerIDs: [String] = []

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        setUpHeader()
        bannerStack.orientation = .vertical
        bannerStack.alignment = .leading
        bannerStack.spacing = 6
        bannerStack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        statusLine.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLine.textColor = .secondaryLabelColor
        statusLine.lineBreakMode = .byTruncatingMiddle
        let line = NSBox()
        line.boxType = .separator
        for subview in [header, bannerStack, container, line, statusLine] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),
            bannerStack.topAnchor.constraint(equalTo: header.bottomAnchor),
            bannerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bannerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.topAnchor.constraint(equalTo: bannerStack.bottomAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            line.topAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusLine.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 4),
            statusLine.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLine.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLine.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -5),
        ])
        view = root
    }

    private func setUpHeader() {
        pathControl.pathStyle = .standard
        pathControl.isEditable = false
        pathControl.focusRingType = .none
        pathControl.target = self
        pathControl.action = #selector(pathClicked)
        pathControl.setAccessibilityLabel("Folder path")
        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        switcher.segmentCount = DiskView.allCases.count
        switcher.trackingMode = .selectOne
        switcher.segmentStyle = .automatic
        switcher.target = self
        switcher.action = #selector(switched)
        switcher.setAccessibilityLabel("View")
        for (index, view) in DiskView.allCases.enumerated() {
            switcher.setImage(NSImage(systemSymbolName: view.symbol, accessibilityDescription: view.title), forSegment: index)
            switcher.setToolTip("\(view.title) (⌘\(index + 1))", forSegment: index)
            switcher.setImageScaling(.scaleProportionallyDown, forSegment: index)
        }
        switcher.setContentHuggingPriority(.required, for: .horizontal)
        switcher.setContentCompressionResistancePriority(.required, for: .horizontal)
        for subview in [pathControl, switcher] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            pathControl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 10),
            pathControl.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            pathControl.trailingAnchor.constraint(lessThanOrEqualTo: switcher.leadingAnchor, constant: -12),
            switcher.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            switcher.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateSwitcherLabels()
    }

    /// Labels next to the icons when there is room for them.
    private func updateSwitcherLabels() {
        let width = view.bounds.width
        for (index, item) in DiskView.allCases.enumerated() {
            let label = width > 1010 ? item.title : width > 860 ? item.shortTitle : ""
            if switcher.label(forSegment: index) != label {
                switcher.setLabel(label, forSegment: index)
                switcher.setWidth(0, forSegment: index)
            }
        }
    }

    func exportableNodes() -> [Int32] {
        let nodes = currentKey.flatMap { controllers[$0] }?.exportableNodes() ?? []
        if !nodes.isEmpty {
            return nodes
        }
        guard let tree = model.tree else { return [] }
        return FileSort().sorted(tree.descendants(of: model.focus) { _ in true }, in: tree)
    }

    // MARK: Following the model

    private func render() {
        let content = model.content
        let key = key(for: content)
        if key != currentKey {
            show(key)
        }
        let isScan = content == .scan
        header.isHidden = !isScan
        if isScan {
            updatePath()
            switcher.selectedSegment = DiskView.allCases.firstIndex(of: model.view) ?? 0
        }
        updateBanners(isScan: isScan)
        updateStatus()
    }

    private func key(for content: DiskAnalyzerModel.Content) -> String {
        switch content {
        case .welcome: "welcome"
        case .scanning: "scanning"
        case .volume, .cloud, .record: "overview"
        case .scan: model.search.isEmpty ? model.view.rawValue : "search"
        }
    }

    private func show(_ key: String) {
        if let currentKey, let old = controllers[currentKey] {
            old.view.removeFromSuperview()
        }
        let controller = controllers[key] ?? makeController(key)
        controllers[key] = controller
        controller.actions = actions
        let view = controller.view
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        currentKey = key
    }

    private func makeController(_ key: String) -> any DiskContentController {
        switch key {
        case "welcome": WelcomeViewController(model: model)
        case "scanning": ScanProgressViewController(model: model)
        case "overview": OverviewViewController(model: model)
        case "search": FileTableViewController(model: model, mode: .search)
        default: makeController(for: DiskView(rawValue: key) ?? .sunburst)
        }
    }

    private func makeController(for view: DiskView) -> any DiskContentController {
        switch view {
        case .sunburst: ChartViewController(model: model, chart: SunburstView())
        case .treemap: ChartViewController(model: model, chart: TreemapView())
        case .list: ListViewController(model: model)
        case .biggest: FileTableViewController(model: model, mode: .biggest)
        case .old: FileTableViewController(model: model, mode: .old)
        case .duplicates: DuplicatesViewController(model: model)
        case .types: FileTypesViewController(model: model)
        case .hogs: SpaceHogsViewController(model: model)
        }
    }

    private func updatePath() {
        let crumbs = model.breadcrumbs
        pathControl.pathItems = crumbs.map { node in
            let item = NSPathControlItem()
            item.title = model.displayName(of: node)
            let symbol = node == ScanTree.rootIndex ? (model.target?.volume?.kind.symbol ?? "folder") : "folder"
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            return item
        }
    }

    @objc private func pathClicked() {
        guard let clicked = pathControl.clickedPathItem, let index = pathControl.pathItems.firstIndex(of: clicked) else { return }
        let crumbs = model.breadcrumbs
        guard crumbs.indices.contains(index) else { return }
        model.focus = crumbs[index]
        model.selection = []
    }

    @objc private func switched() {
        guard DiskView.allCases.indices.contains(switcher.selectedSegment) else { return }
        model.view = DiskView.allCases[switcher.selectedSegment]
        model.search = ""
    }
}
