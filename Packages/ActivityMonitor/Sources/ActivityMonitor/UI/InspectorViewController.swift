import AppKit

/// The details of the selected process, beside the list (⌘I): who it is, live graphs of its CPU and memory, the
/// process's facts, its executable and code signature and, for the user's own processes, its arguments and open files.
/// What comes from disk loads once per selection, off the main thread; the numbers follow every sample.
final class InspectorViewController: NSViewController {
    static let width: CGFloat = 300

    var onSelectPID: ((Int32) -> Void)?
    var onReveal: ((ProcessMetrics) -> Void)?

    let icons: ProcessIconCache
    private let stack = NSStackView()
    private let placeholder = NSTextField(wrappingLabelWithString: "Select a process to see its details.")
    private let header = NSStackView()
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")
    private let cpuTitle = NSTextField(labelWithString: "")
    private let cpuGraph = HistoryGraphView()
    private let memoryTitle = NSTextField(labelWithString: "")
    private let memoryGraph = HistoryGraphView()
    private lazy var live = liveGraphs()
    private let facts = DetailSection("Process")
    private let executable = DetailSection("Executable")
    private let signature = DetailSection("Code Signature")
    private let arguments = DetailSection("Arguments")
    private let files = DetailSection("Open Files and Ports")
    private let note = NSTextField(wrappingLabelWithString: "")
    private var shown: ProcessIdentity?
    private var current: ProcessMetrics?
    private var detailsTask: Task<Void, Never>?

    init(icons: ProcessIconCache) {
        self.icons = icons
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let document = FlippedView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 18, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        configureHeader()
        for field in [placeholder, note] {
            field.font = .systemFont(ofSize: 11)
            field.textColor = .secondaryLabelColor
        }
        for view in [placeholder, header, live, facts, executable, signature, arguments, files, note] {
            stack.addArrangedSubview(view)
        }
        for view in [header, live] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28).isActive = true
        }
        view = scroll
        view.setAccessibilityLabel("Process details")
        showNothing()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let width = max(160, view.bounds.width - 28)
        for section in [facts, executable, signature, arguments, files] {
            section.valueWidth = width - 92
        }
        for field in [placeholder, note] {
            field.preferredMaxLayoutWidth = width
        }
    }

    /// Shows the selection: one process in full, several as a count and totals, none as a hint.
    func show(_ selection: [ProcessMetrics], parent: ProcessMetrics?, history: ProcessHistorySnapshot?, capacity: Int) {
        guard let process = selection.first else {
            showNothing()
            return
        }
        guard selection.count == 1 else {
            showSeveral(selection)
            return
        }
        current = process
        placeholder.isHidden = true
        for view in [header, live, facts, executable] {
            view.isHidden = false
        }
        if shown != process.id {
            shown = process.id
            cpuGraph.series = []
            memoryGraph.series = []
            build(process, parent: parent)
        }
        refresh(process, history: history, capacity: capacity)
    }

    /// The graphs of the selected process, when its history arrives between samples.
    func showHistory(_ history: ProcessHistorySnapshot?, capacity: Int) {
        guard let current else { return }
        refresh(current, history: history, capacity: capacity)
    }

    // MARK: Building

    private func build(_ process: ProcessMetrics, parent: ProcessMetrics?) {
        iconView.image = icons.icon(for: process, size: NSSize(width: 40, height: 40))
        nameField.stringValue = process.name
        nameField.toolTip = process.name
        subtitleField.stringValue = process.app?.bundleID ?? "PID \(process.pid) · \(process.user)"
        subtitleField.toolTip = subtitleField.stringValue
        facts.show([
            ("PID", String(process.pid)),
            ("User", "\(process.user) (\(process.uid))"),
            ("Started", Self.started(process)),
            ("Kind", process.kind.title),
            ("Status", process.status?.title ?? ActivityFormat.dash),
            ("CPU time", ActivityFormat.cpuTime(process.cpuTime)),
            ("Threads", process.isMine ? ActivityFormat.count(process.threads) : nil),
            ("Memory", ActivityFormat.memory(process.memoryForRanking)),
            ("Real memory", process.memory == nil ? nil : ActivityFormat.memory(process.realMemory)),
            ("Disk", process.isMine ? Self.disk(process) : nil),
            ("Power", process.isMine ? ActivityFormat.power(process.power) : nil),
        ])
        if process.pid != process.parentPID {
            facts.add("Parent", view: parentLink(process, parent: parent))
        }
        executable.show([
            ("Path", process.path ?? "Not shared by macOS"),
            ("Bundle ID", process.app?.bundleID),
        ])
        if process.path != nil {
            let reveal = NSButton(title: "Reveal in Finder", target: self, action: #selector(revealClicked))
            reveal.controlSize = .small
            executable.add("", view: reveal)
        }
        note.stringValue = Self.note(for: process)
        note.isHidden = note.stringValue.isEmpty
        signature.isHidden = process.path == nil
        signature.show([("Signed by", "Checking…")])
        arguments.isHidden = true
        files.isHidden = true
        loadDetails(process)
    }

    private func refresh(_ process: ProcessMetrics, history: ProcessHistorySnapshot?, capacity: Int) {
        current = process
        facts.set("Status", process.status?.title ?? ActivityFormat.dash)
        facts.set("CPU time", ActivityFormat.cpuTime(process.cpuTime))
        facts.set("Threads", ActivityFormat.count(process.threads))
        facts.set("Memory", ActivityFormat.memory(process.memoryForRanking))
        facts.set("Real memory", ActivityFormat.memory(process.realMemory))
        facts.set("Disk", Self.disk(process))
        facts.set("Power", ActivityFormat.power(process.power))
        cpuTitle.stringValue = "CPU · " + ActivityFormat.percentWithSign(process.cpuPercent)
        memoryTitle.stringValue = "MEMORY · " + ActivityFormat.memory(process.memoryForRanking)
        cpuGraph.capacity = min(capacity, ActivityHistory.processCapacityLimit)
        memoryGraph.capacity = cpuGraph.capacity
        // Without a history (an update between samples) the graphs keep what they show.
        guard let history else { return }
        let cpu = history.cpu.map { Double($0) }
        cpuGraph.series = [.init(cpu, color: process.heavy.contains(.cpu) ? ActivityColors.heavy : ActivityColors.user)]
        // At least 100 %, so a quiet process does not fill the graph.
        cpuGraph.maximum = max(100, HistoryGraphView.niceCeiling(cpu.filter { !$0.isNaN }.max() ?? 0))
        let memory = history.memory.map { Double($0) }
        memoryGraph.series = [.init(memory, color: process.heavy.contains(.memory) ? ActivityColors.heavy : .systemPurple)]
        cpuGraph.setAccessibilityLabel("CPU history of \(process.name)")
        memoryGraph.setAccessibilityLabel("Memory history of \(process.name)")
    }

    private func loadDetails(_ process: ProcessMetrics) {
        detailsTask?.cancel()
        let pid = process.pid
        let identity = process.id
        let path = process.path
        let isMine = process.isMine
        detailsTask = Task { [weak self] in
            let details = await Task.detached(priority: .userInitiated) {
                ProcessInspector.details(of: pid, path: path, isMine: isMine)
            }.value
            guard !Task.isCancelled, let self, shown == identity else { return }
            showDetails(details)
        }
    }

    private func showDetails(_ details: ProcessDetails) {
        if let info = details.signature {
            signature.show([
                ("Signed by", info.summary),
                ("Identifier", info.identifier),
                ("Sandbox", info.authority == .unsigned ? nil : info.isSandboxed ? "Yes" : "No"),
                ("Runtime", info.authority == .unsigned ? nil : info.hasHardenedRuntime ? "Hardened" : "Not hardened"),
            ])
        }
        if let commandLine = details.commandLine {
            arguments.isHidden = false
            arguments.show([("Command", Self.commandText(commandLine))])
        }
        if let openFiles = details.openFiles {
            files.isHidden = false
            files.show(Self.fileRows(openFiles))
            let refresh = NSButton(title: "Refresh", target: self, action: #selector(refreshFilesClicked))
            refresh.controlSize = .small
            files.add("", view: refresh)
        }
    }

    private func showNothing() {
        shown = nil
        current = nil
        detailsTask?.cancel()
        placeholder.stringValue = "Select a process to see its details."
        placeholder.isHidden = false
        for view in [header, live, facts, executable, signature, arguments, files, note] {
            view.isHidden = true
        }
    }

    private func showSeveral(_ selection: [ProcessMetrics]) {
        showNothing()
        let cpu = selection.compactMap(\.cpuPercent).reduce(0, +)
        let memory = selection.compactMap(\.memoryForRanking).reduce(0, +)
        let totals = "CPU \(ActivityFormat.percentWithSign(cpu)) · Memory \(ActivityFormat.memory(memory))"
        placeholder.stringValue = "\(selection.count) processes selected\n" + totals
    }

    // MARK: Views

    private func configureHeader() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])
        nameField.font = .systemFont(ofSize: 15, weight: .semibold)
        nameField.lineBreakMode = .byTruncatingMiddle
        nameField.isSelectable = true
        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingMiddle
        subtitleField.isSelectable = true
        for field in [nameField, subtitleField] {
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let names = NSStackView(views: [nameField, subtitleField])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 1
        header.setViews([iconView, names], in: .leading)
        header.alignment = .centerY
        header.spacing = 10
    }

    private func liveGraphs() -> NSStackView {
        for title in [cpuTitle, memoryTitle] {
            title.font = .systemFont(ofSize: 10, weight: .semibold)
            title.textColor = .secondaryLabelColor
        }
        let stack = NSStackView(views: [cpuTitle, cpuGraph, memoryTitle, memoryGraph])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(10, after: cpuGraph)
        for graph in [cpuGraph, memoryGraph] {
            graph.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                graph.heightAnchor.constraint(equalToConstant: 50),
                graph.widthAnchor.constraint(equalTo: stack.widthAnchor),
            ])
        }
        return stack
    }

    private func parentLink(_ process: ProcessMetrics, parent: ProcessMetrics?) -> NSView {
        let title = parent.map { "\($0.name) (\($0.pid))" } ?? "PID \(process.parentPID)"
        let link = NSButton(title: title, target: self, action: #selector(parentClicked))
        link.isBordered = false
        link.contentTintColor = .linkColor
        link.font = .systemFont(ofSize: 11)
        link.tag = Int(process.parentPID)
        link.toolTip = "Select \(title)"
        link.setAccessibilityLabel("Parent process, \(title)")
        return link
    }

    @objc private func parentClicked(_ sender: NSButton) {
        onSelectPID?(Int32(sender.tag))
    }

    @objc private func revealClicked() {
        if let current {
            onReveal?(current)
        }
    }

    @objc private func refreshFilesClicked() {
        if let current {
            loadDetails(current)
        }
    }

    // MARK: Words

    static func started(_ process: ProcessMetrics) -> String {
        let date = process.startDate
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return date.formatted(date: .abbreviated, time: .shortened) + " · " + relative.localizedString(for: date, relativeTo: Date())
    }

    static func disk(_ process: ProcessMetrics) -> String {
        "Read \(ActivityFormat.bytes(process.diskRead)) · Written \(ActivityFormat.bytes(process.diskWritten))"
    }

    /// The command line as a shell would take it, arguments with spaces quoted.
    static func commandText(_ commandLine: ProcessCommandLine) -> String {
        let words = commandLine.arguments.isEmpty ? [commandLine.executable] : commandLine.arguments
        return words.map { word in
            word.isEmpty || word.contains(where: { " \"'$\\".contains($0) }) ? "'" + word
                .replacingOccurrences(of: "'", with: "'\\''") + "'" : word
        }.joined(separator: " ")
    }

    static func fileRows(_ files: [OpenFile]) -> [(title: String, value: String?)] {
        let network = files.filter { $0.kind == .tcp || $0.kind == .udp }.count
        let plain = files.filter { $0.kind == .file || $0.kind == .directory }.count
        var rows: [(title: String, value: String?)] = [
            ("Open", "\(files.count): \(plain) files, \(network) network, \(files.count - plain - network) other"),
        ]
        for file in files.prefix(60) {
            let state = file.state.map { " (\($0))" } ?? ""
            rows.append(("\(file.descriptor)", "\(Self.kindName(file.kind)) \(file.detail)\(state)"))
        }
        if files.count > 60 {
            rows.append(("", "and \(files.count - 60) more"))
        }
        return rows
    }

    private static func kindName(_ kind: OpenFile.Kind) -> String {
        switch kind {
        case .file: "File"
        case .directory: "Folder"
        case .tcp: "TCP"
        case .udp: "UDP"
        case .unixSocket: "Unix"
        case .pipe: "Pipe"
        case .other: "Other"
        }
    }

    static func note(for process: ProcessMetrics) -> String {
        if process.pid == 0 {
            return "kernel_task is the macOS kernel. macOS shares its numbers only with administrators."
        }
        guard !process.isMine else { return "" }
        return "macOS shares the arguments, open files, threads, disk use and power of your own processes only."
    }

    /// A scroll view's document that lays out from the top.
    private final class FlippedView: NSView {
        override var isFlipped: Bool {
            true
        }
    }
}
