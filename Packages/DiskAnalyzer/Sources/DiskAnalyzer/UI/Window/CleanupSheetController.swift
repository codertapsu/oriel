import AppKit

/// Clean Up's sheet (PLAN §7.10 item 19): the folder, how safe it is to clean up and what it is, what Oriel found, Apple
/// Intelligence's reading of a folder Oriel does not know, and the ways to get the space back with the recommended one
/// chosen. The window carries out the choice.
final class CleanupSheetController: NSObject {
    enum Explanation {
        case none
        case waiting
        case done(CleanupExplainer.Explanation?)
    }

    let panel = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 580, height: 560),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: true
    )
    /// The method the user chose and the facts it was offered for, once the sheet has closed.
    var onChoose: ((CleanupMethod, CleanupFacts) -> Void)?
    var onReveal: (() -> Void)?
    var onQuit: (([CleanupFacts.App]) -> Void)?

    private let name: String
    private let path: String
    private let icon: NSImage
    private let page = StackPage(insets: NSEdgeInsets(top: 20, left: 22, bottom: 12, right: 22), spacing: 10)
    private let primary = NSButton(title: "Checking…", target: nil, action: nil)
    private let revealButton = NSButton(title: "Show in Finder", target: nil, action: nil)
    private var advice: CleanupAdvice?
    private var facts: CleanupFacts?
    private var explanation = Explanation.none
    private var radios: [NSButton] = []
    private var selection = 0

    init(name: String, path: String, icon: NSImage) {
        self.name = name
        self.path = path
        self.icon = icon
        super.init()
        primary.target = self
        primary.action = #selector(choose)
        primary.keyEquivalent = "\r"
        revealButton.target = self
        revealButton.action = #selector(reveal)
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [cancel, spacer, revealButton, primary])
        buttons.edgeInsets = NSEdgeInsets(top: 10, left: 20, bottom: 16, right: 20)
        let content = NSView()
        for view in [page, buttons] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            page.topAnchor.constraint(equalTo: content.topAnchor),
            buttons.topAnchor.constraint(equalTo: page.bottomAnchor),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        panel.contentMinSize = CGSize(width: 520, height: 380)
        panel.setAccessibilityLabel("Clean Up “\(name)”")
        render()
    }

    /// Shows the advice; `explaining` while Apple Intelligence is asked.
    func show(_ advice: CleanupAdvice, facts: CleanupFacts, explaining: Bool) {
        self.advice = advice
        self.facts = facts
        explanation = explaining ? .waiting : .none
        selection = 0
        render()
    }

    /// Apple Intelligence's reading, with the advice it may have made more cautious.
    func show(_ explanation: CleanupExplainer.Explanation?, advice: CleanupAdvice) {
        self.advice = advice
        self.explanation = .done(explanation)
        render()
    }

    func close() {
        panel.sheetParent?.endSheet(panel)
    }

    // MARK: Contents

    private func render() {
        var views: [NSView] = [header()]
        guard let advice else {
            views.append(progress("Checking “\(name)”…"))
            page.show(views)
            primary.title = "Checking…"
            primary.isEnabled = false
            revealButton.isHidden = false
            return
        }
        views.append(PageParts.separator())
        views.append(verdict(advice.verdict))
        views.append(PageParts.text(advice.summary, secondary: false))
        if let afterwards = advice.afterwards {
            views.append(PageParts.text(afterwards))
        }
        if !advice.findings.isEmpty {
            views.append(PageParts.heading("What Oriel found"))
            views += advice.findings.map(finding)
            if !advice.appsToQuit.isEmpty {
                let names = ListFormatter.localizedString(byJoining: advice.appsToQuit.map(\.name))
                views.append(NSButton(title: "Quit \(names)", target: self, action: #selector(quit)))
            }
        }
        views += explanationViews()
        views.append(PageParts.heading(advice.methods.isEmpty ? "Nothing to do here" : "How to get the space back"))
        if advice.methods.isEmpty {
            views.append(PageParts.text("macOS manages it by itself."))
        }
        radios = []
        for (index, method) in advice.methods.enumerated() {
            views.append(row(for: method, at: index))
        }
        page.show(views)
        updateButtons()
    }

    private func header() -> NSView {
        let image = NSImageView(image: icon)
        image.imageScaling = .scaleProportionallyUpOrDown
        image.widthAnchor.constraint(equalToConstant: 40).isActive = true
        image.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let title = PageParts.title(name, size: 15)
        let place = PageParts.text(path, size: NSFont.smallSystemFontSize)
        place.lineBreakMode = .byCharWrapping
        var texts: [NSView] = [title, place]
        if let facts {
            let size = DiskFormat.bytes(facts.bytes)
            let files = DiskFormat.count(facts.fileCount, "file")
            texts.append(PageParts.text("\(size), \(files)", size: NSFont.smallSystemFontSize))
        }
        let stack = NSStackView(views: texts)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        place.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [image, stack])
        row.alignment = .top
        row.spacing = 12
        return row
    }

    private func verdict(_ verdict: CleanupVerdict) -> NSView {
        let symbol = PageParts.icon(verdict.symbol, size: 16, tint: Self.color(of: verdict))
        symbol.setAccessibilityLabel(verdict.title)
        let title = PageParts.heading(verdict.title)
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        let row = NSStackView(views: [symbol, title])
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    private func finding(_ finding: CleanupFinding) -> NSView {
        let symbol = PageParts.icon(finding.symbol, size: 12, tint: Self.color(of: finding.kind))
        symbol.setContentHuggingPriority(.required, for: .horizontal)
        let text = PageParts.text(finding.text, secondary: false, size: NSFont.smallSystemFontSize + 1)
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [symbol, text])
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    private func explanationViews() -> [NSView] {
        switch explanation {
        case .none:
            return []
        case .waiting:
            return [PageParts.heading("Apple Intelligence"), progress("Asking Apple Intelligence what this folder is…")]
        case let .done(reading):
            guard let reading else {
                return [PageParts.heading("Apple Intelligence"), PageParts.text("Apple Intelligence could not say what this folder is.")]
            }
            var views: [NSView] = [PageParts.heading("Apple Intelligence"), PageParts.text(reading.text, secondary: false)]
            if let owner = reading.owner {
                views.append(PageParts.text("Made by: \(owner)", size: NSFont.smallSystemFontSize))
            }
            views.append(PageParts.text(
                "Apple Intelligence can be wrong. It never makes Oriel's advice less careful.", size: NSFont.smallSystemFontSize
            ))
            return views
        }
    }

    private func row(for method: CleanupMethod, at index: Int) -> NSView {
        let title = index == 0 ? method.title + " (recommended)" : method.title
        let radio = NSButton(radioButtonWithTitle: title, target: self, action: #selector(pick(_:)))
        radio.tag = index
        radio.state = index == selection ? .on : .off
        radios.append(radio)
        var detail = method.detail
        if let bytes = method.bytes, bytes > 0 {
            detail += " Frees about \(DiskFormat.bytes(bytes))."
        }
        let text = PageParts.text(detail, size: NSFont.smallSystemFontSize)
        let indented = NSStackView(views: [text])
        indented.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        let stack = NSStackView(views: [radio, indented])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private func progress(_ text: String) -> NSView {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        let row = NSStackView(views: [spinner, PageParts.text(text)])
        row.spacing = 8
        return row
    }

    private func updateButtons() {
        guard let advice else { return }
        guard advice.methods.indices.contains(selection) else {
            primary.title = "Done"
            primary.isEnabled = true
            revealButton.isHidden = false
            return
        }
        let method = advice.methods[selection]
        primary.title = switch method.action {
        case .trashFolder, .trashContents, .trashItems: "Move to Trash…"
        case .run: "Run…"
        case .copyCommand: "Copy Command"
        case let .openApp(_, name): "Open \(name)"
        case .showOldFiles: "Show Old Files"
        case .reveal: "Show in Finder"
        }
        primary.isEnabled = true
        revealButton.isHidden = method.action == .reveal
    }

    static func color(of verdict: CleanupVerdict) -> NSColor {
        switch verdict {
        case .safe: .systemGreen
        case .careful: .systemOrange
        case .review: .systemBlue
        case .keep: .systemRed
        }
    }

    static func color(of kind: CleanupFinding.Kind) -> NSColor {
        switch kind {
        case .good: .systemGreen
        case .note: .secondaryLabelColor
        case .warning: .systemOrange
        case .stop: .systemRed
        }
    }

    // MARK: Actions

    @objc private func pick(_ sender: NSButton) {
        selection = sender.tag
        for radio in radios {
            radio.state = radio.tag == selection ? .on : .off
        }
        updateButtons()
    }

    @objc private func choose() {
        let method = advice.flatMap { $0.methods.indices.contains(selection) ? $0.methods[selection] : nil }
        close()
        if let method, let facts {
            onChoose?(method, facts)
        }
    }

    @objc private func reveal() {
        close()
        onReveal?()
    }

    @objc private func quit() {
        guard let apps = advice?.appsToQuit, !apps.isEmpty else { return }
        onQuit?(apps)
    }

    @objc private func cancel() {
        close()
    }
}
