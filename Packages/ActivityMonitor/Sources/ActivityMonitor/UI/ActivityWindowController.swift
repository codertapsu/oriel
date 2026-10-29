import AppKit
import OrielCore
import SharedUI

/// Activity Monitor's window: tabs, a view menu and search in the toolbar over the process list, the top consumers
/// above it, the Mac's summary under it and the selected process's details beside it.
///
/// Sampling starts when the window opens and stops when it closes. While the window is hidden behind others or in
/// the Dock, samples skip `ps` and nettop and the views are not redrawn; the graphs' history keeps going.
final class ActivityWindowController: NSWindowController, NSWindowDelegate {
    static let defaultSize = CGSize(width: 1140, height: 740)
    static let minimumSize = CGSize(width: 780, height: 500)
    static let autosaveName = "ActivityMonitorWindow"

    let settings: SettingsStore
    /// Opens Settings at Activity Monitor.
    var openSettings: (() -> Void)?
    /// Called once the window has closed and sampling has stopped.
    var onClose: (() -> Void)?

    let model = ActivityListModel()
    let list: ProcessListController
    let summary = SummaryView()
    let topStrip = TopConsumersView()
    let inspector: InspectorViewController
    let split = NSSplitViewController()
    let policy = SignalPolicy(ownPID: getpid(), myUID: geteuid())
    let tabs = NSSegmentedControl(labels: ActivityTab.allCases.map(\.title), trackingMode: .selectOne, target: nil, action: nil)
    let searchItem = NSSearchToolbarItem(itemIdentifier: .activitySearch)
    let actionsMenu = NSMenu()
    let filterMenu = NSMenu()
    var thresholds = HeavyThresholds()
    private(set) var session: SamplingSession?
    private(set) var inspectorItem: NSSplitViewItem?
    /// False while the window is minimized or covered; samples are lighter and the views wait.
    private(set) var isOnScreen = true
    private var settingsObserver: (any NSObjectProtocol)?
    private var thermalObserver: (any NSObjectProtocol)?
    private var pressureSource: (any DispatchSourceMemoryPressure)?

    /// Whether the window and the lists remember their frame and columns in the app's defaults; off in tests.
    private let autosaves: Bool

    init(settings: SettingsStore, autosaves: Bool = true) {
        self.settings = settings
        self.autosaves = autosaves
        list = ProcessListController(model: model, autosaves: autosaves)
        inspector = InspectorViewController(icons: list.icons)
        let window = ActivityWindow(
            contentRect: CGRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init(window: window)
        window.delegate = self
        readSettings()
        configure(window)
        connect()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Opens the window in front and starts sampling.
    func present() {
        guard let window else { return }
        startSampling()
        // Oriel is a menu-bar app: activate it, or the window opens behind the app the user is in.
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(list.outline)
    }

    // MARK: Sampling

    private func startSampling() {
        guard session == nil else { return }
        let session = SamplingSession(
            interval: .seconds(ActivitySettings.intervalSeconds(in: settings)),
            historyCapacity: ActivitySettings.historyCapacity(in: settings),
            request: { [weak self] in self?.request() ?? SampleRequest(sources: []) },
            deliver: { [weak self] in self?.apply($0) }
        )
        self.session = session
        session.start()
        observeSystem()
    }

    private func stopSampling() {
        session?.stop()
        session = nil
        pressureSource?.cancel()
        pressureSource = nil
        for observer in [settingsObserver, thermalObserver].compactMap(\.self) {
            NotificationCenter.default.removeObserver(observer)
        }
        settingsObserver = nil
        thermalObserver = nil
    }

    /// What the next sample reads: only cheap sources while nobody can see the window.
    func request() -> SampleRequest {
        SampleRequest(
            sources: isOnScreen ? model.sources : model.sources.intersection(.devices),
            apps: RunningApps.catalog(),
            selected: list.selectedProcesses.first?.id,
            thresholds: thresholds,
            historyCapacity: ActivitySettings.historyCapacity(in: settings)
        )
    }

    func apply(_ snapshot: ActivitySnapshot) {
        model.update(snapshot)
        guard isOnScreen else { return }
        list.reload()
        summary.update(tab: model.tab, snapshot: snapshot)
        updateTopStrip()
        updateInspector(history: snapshot.selectedHistory)
        window?.toolbar?.validateVisibleItems()
    }

    /// Memory pressure and thermal changes are events, not samples: each brings the next sample forward.
    private func observeSystem() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.session?.wake() }
        }
        source.resume()
        pressureSource = source
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.session?.wake() }
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: .main
        ) { [weak self] notification in
            let key = notification.userInfo?["key"] as? String ?? ""
            MainActor.assumeIsolated { self?.settingsChanged(key) }
        }
    }

    // MARK: Views

    func refreshViews() {
        list.reload()
        summary.update(tab: model.tab, snapshot: model.snapshot)
        updateTopStrip()
        updateInspector(history: nil)
        window?.toolbar?.validateVisibleItems()
    }

    func updateTopStrip() {
        let tab = model.tab
        let items = model.topConsumers().map { process in
            TopConsumersView.Item(
                process: process,
                value: Self.measureText(process, tab: tab),
                heavyNote: process.heavy.contains(tab.heavyFlag) ? heavyNote(for: process) : nil
            )
        }
        let noun = Self.measureName(tab)
        topStrip.update(
            title: "Using the most \(noun):",
            emptyText: model.snapshot == nil ? "" : "Nothing is using much \(noun) right now.",
            items: items,
            icons: list.icons,
            status: statusText()
        )
    }

    private func statusText() -> String {
        guard let snapshot = model.snapshot else { return "" }
        let total = model.visibleProcesses.count
        let shown = model.shownCount
        var text = shown == total
            ? ActivityFormat.count(total, "process", "processes")
            : "\(shown.formatted()) of \(total.formatted()) processes"
        if model.onlyMine {
            text += " · yours only"
        }
        if model.sources.contains(.otherUsers), !snapshot.sources.contains(.otherUsers), isOnScreen, snapshot.interval != nil {
            text += " · other users' CPU unavailable"
        }
        return text
    }

    func updateInspector(history: ProcessHistorySnapshot?) {
        let selection = list.selectedProcesses
        let parent = selection.first.flatMap { process in model.snapshot?.processes.first { $0.pid == process.parentPID } }
        inspector.show(selection, parent: parent, history: history, capacity: model.snapshot?.history.capacity ?? 150)
    }

    /// What the flame says: which thresholds the process is over.
    func heavyNote(for process: ProcessMetrics) -> String? {
        guard !process.heavy.isEmpty else { return nil }
        var parts: [String] = []
        if process.heavy.contains(.cpu) {
            parts.append("over \(Int(thresholds.cpuPercent)) % CPU for \(Int(thresholds.seconds)) s")
        }
        if process.heavy.contains(.memory) {
            parts.append("over \(ActivityFormat.bytes(thresholds.memoryBytes)) of memory")
        }
        if process.heavy.contains(.disk) {
            parts.append("over \(ActivityFormat.rate(thresholds.diskBytesPerSecond)) of disk for \(Int(thresholds.seconds)) s")
        }
        if process.heavy.contains(.network) {
            parts.append("over \(ActivityFormat.rate(thresholds.networkBytesPerSecond)) of network for \(Int(thresholds.seconds)) s")
        }
        return parts.joined(separator: ", ")
    }

    static func measureName(_ tab: ActivityTab) -> String {
        switch tab {
        case .cpu: "CPU"
        case .memory: "memory"
        case .energy: "power"
        case .disk: "disk"
        case .network: "network"
        }
    }

    static func measureText(_ process: ProcessMetrics, tab: ActivityTab) -> String {
        switch tab {
        case .cpu: ActivityFormat.percentWithSign(process.cpuPercent)
        case .memory: ActivityFormat.memory(process.memoryForRanking)
        case .energy: ActivityFormat.power(process.power)
        case .disk: ActivityFormat.rate(process.diskPerSecond)
        case .network: ActivityFormat.rate(process.network?.total)
        }
    }

    // MARK: Tabs, views and search

    func select(tab: ActivityTab) {
        let before = model.sources
        model.tab = tab
        tabs.selectedSegment = ActivityTab.allCases.firstIndex(of: tab) ?? 0
        list.show(tab)
        refreshViews()
        wakeIfNeeded(before)
    }

    func select(filter: ViewFilter) {
        let before = model.sources
        model.filter = filter
        settings[ActivitySettings.viewFilter] = filter.rawValue
        window?.subtitle = model.effectiveFilter.title
        refreshViews()
        wakeIfNeeded(before)
    }

    /// A tab or view that needs `ps` or nettop gets its first rates within a second.
    private func wakeIfNeeded(_ before: SampleSources) {
        if !model.sources.subtracting(before).isEmpty {
            session?.wake(followUp: .seconds(1))
        }
    }

    func focusSearch() {
        searchItem.beginSearchInteraction()
    }

    func toggleInspector() {
        split.toggleInspector(nil)
        settings[ActivitySettings.showsInspector] = inspectorItem?.isCollapsed == false
    }

    /// Selects the process with `pid`, showing every process first if the current view leaves it out.
    func selectProcess(pid: Int32) {
        guard let process = model.snapshot?.processes.first(where: { $0.pid == pid }) else { return }
        select(process.id)
    }

    func select(_ identity: ProcessIdentity) {
        if !model.roots.contains(where: { $0.allProcesses.contains { $0.id == identity } }) {
            searchItem.searchField.stringValue = ""
            model.query = ""
            if model.filter != .all {
                select(filter: .all)
            } else {
                list.reload()
            }
        }
        list.select(identity)
    }

    // MARK: Settings

    private func readSettings() {
        model.tab = ActivityTab(rawValue: settings[ActivitySettings.defaultTab]) ?? .cpu
        model.filter = ViewFilter(rawValue: settings[ActivitySettings.viewFilter]) ?? .all
        model.onlyMine = settings[ActivitySettings.onlyMyProcesses]
        model.sorts = Dictionary(uniqueKeysWithValues: ActivityTab.allCases.map { ($0, settings[ActivitySettings.sort(for: $0)]) })
        thresholds = ActivitySettings.thresholds(in: settings)
    }

    private func settingsChanged(_ key: String) {
        guard key.hasPrefix(ActivitySettings.prefix) else { return }
        session?.setInterval(.seconds(ActivitySettings.intervalSeconds(in: settings)))
        thresholds = ActivitySettings.thresholds(in: settings)
        let before = model.sources
        model.onlyMine = settings[ActivitySettings.onlyMyProcesses]
        window?.subtitle = model.effectiveFilter.title
        rebuildFilterMenu()
        refreshViews()
        wakeIfNeeded(before)
    }

    // MARK: NSWindowDelegate

    func windowDidChangeOcclusionState(_: Notification) {
        let visible = window?.occlusionState.contains(.visible) ?? false
        guard visible != isOnScreen else { return }
        isOnScreen = visible
        if visible {
            refreshViews()
            session?.wake(followUp: .seconds(1))
        }
    }

    func windowWillClose(_: Notification) {
        stopSampling()
        onClose?()
    }

    // MARK: Layout

    private func configure(_ window: ActivityWindow) {
        window.title = "Activity Monitor"
        window.subtitle = model.effectiveFilter.title
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.isRestorable = false
        window.contentMinSize = Self.minimumSize
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .documentWindow
        window.toolbarStyle = .unified
        window.toolbar = makeToolbar()
        window.onKeyEquivalent = { [weak self] event in self?.handleKeyEquivalent(event) ?? false }
        let main = NSViewController()
        main.view = makeContent()
        let inspectorItem = NSSplitViewItem(inspectorWithViewController: inspector)
        inspectorItem.minimumThickness = 260
        inspectorItem.maximumThickness = 440
        inspectorItem.isCollapsed = !settings[ActivitySettings.showsInspector]
        self.inspectorItem = inspectorItem
        split.splitViewItems = [NSSplitViewItem(viewController: main), inspectorItem]
        window.contentViewController = split
        window.setContentSize(Self.defaultSize)
        if !autosaves || !window.setFrameUsingName(Self.autosaveName), let screen = ScreenLocator.screenUnderMouse {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        if autosaves {
            window.setFrameAutosaveName(Self.autosaveName)
        }
        list.show(model.tab)
        summary.update(tab: model.tab, snapshot: nil)
        updateTopStrip()
    }

    private func makeContent() -> NSView {
        let content = NSView()
        let top = NSBox()
        top.boxType = .separator
        let bottom = NSBox()
        bottom.boxType = .separator
        for view in [topStrip, top, list.container, bottom, summary] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            topStrip.topAnchor.constraint(equalTo: content.topAnchor),
            topStrip.heightAnchor.constraint(equalToConstant: TopConsumersView.height),
            top.topAnchor.constraint(equalTo: topStrip.bottomAnchor),
            list.container.topAnchor.constraint(equalTo: top.bottomAnchor),
            list.container.bottomAnchor.constraint(equalTo: bottom.topAnchor),
            bottom.bottomAnchor.constraint(equalTo: summary.topAnchor),
            summary.heightAnchor.constraint(equalToConstant: SummaryView.height),
            summary.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        for view in [topStrip, top, list.container, bottom, summary] as [NSView] {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
        }
        return content
    }

    private func connect() {
        list.onSelectionChange = { [weak self] in self?.selectionChanged() }
        list.onOpen = { [weak self] in self?.showInspector() }
        list.onSortChange = { [weak self] sort in self?.sortChanged(sort) }
        list.onCopy = { [weak self] in self?.copySelection() }
        list.heavyNote = { [weak self] process in self?.heavyNote(for: process) }
        list.contextMenu.delegate = self
        actionsMenu.delegate = self
        topStrip.onSelect = { [weak self] identity in self?.select(identity) }
        inspector.onSelectPID = { [weak self] pid in self?.selectProcess(pid: pid) }
        inspector.onReveal = { [weak self] process in self?.reveal(process) }
        tabs.target = self
        tabs.action = #selector(tabClicked)
        tabs.selectedSegment = ActivityTab.allCases.firstIndex(of: model.tab) ?? 0
        searchItem.searchField.delegate = self
    }

    private func selectionChanged() {
        updateInspector(history: nil)
        window?.toolbar?.validateVisibleItems()
        guard let session, list.selectedProcesses.count == 1, let identity = list.selectedProcesses.first?.id else { return }
        Task { [weak self] in
            let history = await session.sampler.history(of: identity)
            guard let self, list.selectedProcesses.first?.id == identity else { return }
            inspector.showHistory(history, capacity: model.snapshot?.history.capacity ?? 150)
        }
    }

    private func sortChanged(_ sort: ProcessSort) {
        model.sorts[model.tab] = sort
        settings[ActivitySettings.sort(for: model.tab)] = sort
        list.reload()
    }

    func showInspector() {
        if inspectorItem?.isCollapsed == true {
            toggleInspector()
        }
    }

    @objc private func tabClicked(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        guard ActivityTab.allCases.indices.contains(index) else { return }
        select(tab: ActivityTab.allCases[index])
    }

    /// ⌘F search, ⌘I details, ⌥⌘Q quit, ⌘1–⌘5 tabs.
    private func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (flags, key) {
        case ([.command], "f"):
            focusSearch()
        case ([.command], "i"):
            toggleInspector()
        case ([.command, .option], "q"):
            quitSelection(force: false)
        case let ([.command], digit) where Int(digit).map { (1 ... ActivityTab.allCases.count).contains($0) } == true:
            select(tab: ActivityTab.allCases[(Int(digit) ?? 1) - 1])
        default:
            return false
        }
        return true
    }
}

extension ActivityWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_: Notification) {
        searchChanged()
    }

    /// Esc and the clear button end the search without a text change of their own.
    func searchFieldDidEndSearching(_: NSSearchField) {
        searchChanged()
    }

    private func searchChanged() {
        guard model.query != searchItem.searchField.stringValue else { return }
        model.query = searchItem.searchField.stringValue
        list.reload()
        updateTopStrip()
    }
}
