import AppKit

/// The main area while a scan runs: what has been found so far, the folder being read, and Stop.
final class ScanProgressViewController: NSViewController, DiskContentController {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let spinner = NSProgressIndicator()
    private let heading = PageParts.title("", size: 17)
    private let counts = NSTextField(labelWithString: "")
    private let path = NSTextField(labelWithString: "")
    private let note = PageParts.text("", size: NSFont.smallSystemFontSize)

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        heading.alignment = .center
        counts.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        counts.alignment = .center
        path.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle
        path.alignment = .center
        note.alignment = .center
        let stop = NSButton(title: "Stop", target: self, action: #selector(stop))
        let stack = NSStackView(views: [spinner, heading, counts, path, note, stop])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView()
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -30),
            stack.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, constant: -60),
            path.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            note.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        spinner.startAnimation(nil)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        spinner.stopAnimation(nil)
    }

    private func render() {
        heading.stringValue = "Scanning “\(model.target?.displayName ?? "")”…"
        guard case let .scanning(progress) = model.phase else { return }
        counts.stringValue = [
            DiskFormat.count(progress.files, "file"), DiskFormat.count(progress.folders, "folder"), DiskFormat.bytes(progress.bytes),
        ].joined(separator: " · ")
        path.stringValue = progress.currentPath
        note.stringValue = progress.unreadableFolders > 0
            ? "\(DiskFormat.count(progress.unreadableFolders, "folder")) could not be read so far."
            : "If macOS asks whether Oriel may see a folder, choose Allow to count it."
        view.setAccessibilityLabel("\(heading.stringValue) \(counts.stringValue)")
    }

    @objc private func stop() {
        model.stopScan()
    }
}
