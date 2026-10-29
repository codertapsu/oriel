import AppKit

/// What the sidebar's selection is before it is scanned: a volume's capacity, purgeable space with what it is, local
/// snapshots and the Trash; a cloud folder and why its plan is not shown; a folder scanned before.
final class OverviewViewController: NSViewController, DiskContentController {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let page = StackPage(insets: NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28))

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
        switch model.content {
        case let .volume(volume): page.show(volumeViews(volume))
        case let .cloud(location): page.show(cloudViews(location))
        case let .record(record): page.show(recordViews(record))
        default: page.show([])
        }
    }

    // MARK: Volumes

    private func volumeViews(_ volume: VolumeInfo) -> [NSView] {
        let usage = volume.usage
        let bar = CapacityBarView()
        bar.usage = usage
        bar.heightAnchor.constraint(equalToConstant: 14).isActive = true
        var views: [NSView] = [
            header(
                symbol: volume.kind.symbol,
                title: volume.name,
                detail: [volume.format, volume.kind.title].filter { !$0.isEmpty }
                    .joined(separator: " · ")
            ),
            bar,
            PageParts.facts([
                .init(
                    "Used",
                    DiskFormat.bytes(usage.usedWithoutPurgeable),
                    swatch: usage.isNearlyFull ? .systemOrange : .controlAccentColor
                ),
                .init("Purgeable", DiskFormat.bytes(usage.purgeable), swatch: NSColor.controlAccentColor.withAlphaComponent(0.35)),
                .init("Free", DiskFormat.bytes(usage.available), swatch: .quaternaryLabelColor),
                .init("Capacity", DiskFormat.bytes(usage.total)),
            ]),
            ButtonRow(volumeButtons(volume)),
            PageParts.separator(),
            PageParts.heading("Purgeable space"),
            PageParts.text(Self.purgeableNote),
        ]
        if volume.canHaveLocalSnapshots {
            views += snapshotViews(volume)
        }
        if volume.kind == .startup {
            views += [
                PageParts.separator(),
                PageParts.heading("Trash"),
                PageParts.text("What you move to the Trash still takes space until you empty it. Emptying it is up to you, in Finder."),
                ButtonRow([("Open Trash", { SystemLinks.openTrash() })], primaryFirst: false),
            ]
        }
        return views
    }

    private func volumeButtons(_ volume: VolumeInfo) -> [(title: String, action: () -> Void)] {
        let scan: () -> Void = { [weak self] in self?.actions?.scan(volume.path) }
        var buttons: [(title: String, action: () -> Void)] = [("Scan “\(volume.name)”", scan)]
        if volume.kind == .startup {
            buttons.append(("Storage Settings…", { SystemLinks.open(SystemLinks.storageSettings) }))
        }
        buttons.append(("Reveal in Finder", { SystemLinks.reveal([volume.url]) }))
        if volume.canEject {
            buttons.append(("Eject", { [weak self] in self?.actions?.eject(volume) }))
        }
        return buttons
    }

    private func snapshotViews(_ volume: VolumeInfo) -> [NSView] {
        var views: [NSView] = [PageParts.separator(), PageParts.heading("Local Time Machine snapshots")]
        guard let snapshots = model.localSnapshots[volume.path] else {
            model.loadLocalSnapshots(of: volume)
            return views + [PageParts.text("Looking for local snapshots…")]
        }
        guard !snapshots.isEmpty else {
            return views + [PageParts.text("There are none on this volume.")]
        }
        let newest = snapshots.compactMap(\.date).max()
        views.append(PageParts.text("""
        \(DiskFormat.count(snapshots.count, "snapshot")), the newest from \(DiskFormat.date(newest)). Time Machine keeps them \
        while there is room, as part of the purgeable space, and macOS removes them when space is needed.
        """))
        views.append(ButtonRow([("Remove Snapshots…", { [weak self] in self?.actions?.thinSnapshots(of: volume) })], primaryFirst: false))
        return views
    }

    private static let purgeableNote = """
    Space macOS frees by itself when something needs it: local Time Machine snapshots, iCloud files that are safely in \
    iCloud, and caches apps mark as purgeable. Large downloads and copies can use it, so it counts as available, but \
    Finder shows it as used. Oriel never deletes it behind your back; remove snapshots below, or remove iCloud downloads \
    from a scan of iCloud Drive.
    """

    // MARK: Cloud and remembered scans

    private func cloudViews(_ location: CloudLocation) -> [NSView] {
        let scan: () -> Void = { [weak self] in self?.actions?.scan(location.path) }
        var buttons: [(title: String, action: () -> Void)] = [("Scan “\(location.title)”", scan)]
        if let page = location.provider.storagePage {
            buttons.append((location.provider == .iCloud ? "iCloud Settings…" : "Open Storage Plan", { SystemLinks.open(page) }))
        }
        buttons.append(("Reveal in Finder", { SystemLinks.reveal([URL(fileURLWithPath: location.path)]) }))
        return [
            header(symbol: location.provider.symbol, title: location.title, detail: location.account ?? location.path),
            PageParts.text("""
            A scan shows how much of \(location.title) is downloaded on this Mac and how much is only in the cloud. Files \
            that are only in the cloud are never downloaded by a scan.
            """, secondary: false),
            PageParts.text("""
            How much of the plan is used and free is not something macOS tells apps, so Oriel cannot show it. The \
            provider's own page has it.
            """),
            ButtonRow(buttons),
        ]
    }

    private func recordViews(_ record: ScanRecord) -> [NSView] {
        [
            header(symbol: "clock.arrow.circlepath", title: record.displayName, detail: record.rootPath),
            PageParts.text(
                "Last scanned \(DiskFormat.date(record.date)): \(DiskFormat.bytes(record.totalBytes)) in "
                    + "\(DiskFormat.count(record.files, "file")).",
                secondary: false
            ),
            PageParts.text("Scan it again to see it, and what grew since then."),
            ButtonRow([
                ("Scan Again", { [weak self] in self?.actions?.scan(record.rootPath) }),
                ("Reveal in Finder", { SystemLinks.reveal([URL(fileURLWithPath: record.rootPath)]) }),
                ("Forget", { [weak self] in self?.model.forgetScans(of: record.rootPath) }),
            ]),
        ]
    }

    private func header(symbol: String, title: String, detail: String) -> NSView {
        let texts = NSStackView(views: [PageParts.title(title), PageParts.text(detail)])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 2
        let row = NSStackView(views: [PageParts.icon(symbol, size: 34), texts])
        row.spacing = 12
        row.alignment = .centerY
        return row
    }
}
