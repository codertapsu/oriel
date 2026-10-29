import AppKit

/// Hosts the sunburst or the treemap and keeps it on the folder and selection the model has.
final class ChartViewController: NSViewController, DiskContentController {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let chart: ChartView

    init(model: DiskAnalyzerModel, chart: ChartView) {
        self.model = model
        self.chart = chart
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        chart.onOpen = { [weak self] node in self?.model.open(node) }
        chart.onSelect = { [weak self] nodes in self?.model.selection = nodes }
        chart.onUp = { [weak self] in self?.model.goUp() }
        chart.menuProvider = { [weak self] node in
            guard let self, let actions else { return nil }
            return actions.menu(for: node.map { [$0] } ?? [])
        }
        chart.nameProvider = { [weak self] node in self?.model.displayName(of: node) ?? "" }
        view = chart
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(chart)
    }

    private func render() {
        let version = model.treeVersion
        guard let tree = model.tree, tree.contains(model.focus) else { return }
        chart.show(tree, root: model.focus, selection: Set(model.selection), version: version)
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            actions?.quickLook()
            return
        }
        super.keyDown(with: event)
    }
}
