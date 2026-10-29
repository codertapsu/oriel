import AppKit

/// What the window shows before anything is chosen: what it does, and the two ways to start.
final class WelcomeViewController: NSViewController, DiskContentController {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let page = StackPage(insets: NSEdgeInsets(top: 60, left: 48, bottom: 40, right: 48), spacing: 16)

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = page
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    private func render() {
        let startup = model.volumes.first { $0.kind == .startup }
        var buttons: [(title: String, action: () -> Void)] = []
        if let startup {
            buttons.append(("Scan “\(startup.name)”", { [weak self] in self?.actions?.scan(startup.path) }))
        }
        buttons.append(("Choose Folder…", { [weak self] in self?.actions?.chooseFolder() }))
        page.show([
            PageParts.icon("internaldrive", size: 44, tint: .secondaryLabelColor),
            PageParts.title("See where the space goes"),
            PageParts.text("""
            Choose a volume, a cloud folder or a folder you scanned before in the sidebar, or pick any folder. Oriel reads \
            it and shows what takes the space: as a sunburst, a treemap or a list, with the biggest and oldest files, \
            duplicates, file types and the usual space hogs.
            """),
            ButtonRow(buttons),
            PageParts.text(
                "Nothing is changed without asking: items go to the Trash, and macOS and your own folders are protected.",
                size: NSFont.smallSystemFontSize
            ),
        ])
    }
}
