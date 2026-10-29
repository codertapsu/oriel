import AppKit
import UniformTypeIdentifiers

/// The top of the file window: the file's icon, name and summary, then the provider, the target language and the
/// glossary, each of which translates the file again when changed.
@MainActor
final class FileTranslationHeader: NSView {
    private let actions: FileTranslationActions
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let summary = NSTextField(labelWithString: "")
    private let providerPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let targetPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let glossaryPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private var shownProviders: [TranslationSessionModel.ProviderChoice] = []
    private var shownTargets: [String] = []
    private var shownGlossaries: [UUID?] = []

    init(actions: FileTranslationActions) {
        self.actions = actions
        super.init(frame: .zero)
        build()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        summary.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summary.textColor = .secondaryLabelColor
        summary.lineBreakMode = .byTruncatingTail
        for label in [title, summary] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let names = NSStackView(views: [title, summary])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 1
        // Hugs its lines, so a name without a summary line sits centred beside the icon.
        names.detachesHiddenViews = true
        names.setHuggingPriority(.required, for: .vertical)
        names.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // In a narrow window the pop-ups give up their spare width before the file's name drops below this.
        let readable = names.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        readable.priority = .defaultHigh
        readable.isActive = true

        configure(providerPopUp, label: "Translation provider", action: #selector(providerChosen))
        configure(targetPopUp, label: "Translate into", action: #selector(targetChosen))
        configure(glossaryPopUp, label: "Glossary", action: #selector(glossaryChosen))
        let arrow = NSImageView(image: NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil) ?? NSImage())
        arrow.contentTintColor = .secondaryLabelColor

        let stack = NSStackView()
        stack.setViews([icon, names], in: .leading)
        stack.setViews([providerPopUp, arrow, targetPopUp, glossaryPopUp], in: .trailing)
        stack.alignment = .centerY
        stack.spacing = 8
        stack.setCustomSpacing(10, after: icon)
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // A fixed height: a stack's edge insets give way to the split view below otherwise.
        heightAnchor.constraint(equalToConstant: 52).isActive = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configure(_ popUp: NSPopUpButton, label: String, action: Selector) {
        popUp.target = self
        popUp.action = action
        popUp.toolTip = label
        popUp.setAccessibilityLabel(label)
        popUp.setContentHuggingPriority(.required, for: .horizontal)
        // Sized for its longest item; the selected one is usually much shorter, so it can give some width up, but
        // never so much that its own title is cut (`minimumWidths`).
        popUp.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(300), for: .horizontal)
        let minimum = popUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        minimum.priority = NSLayoutConstraint.Priority(760)
        minimum.isActive = true
        minimumWidths[ObjectIdentifier(popUp)] = minimum
    }

    /// Each pop-up's room for its selected title, updated as the selection changes.
    private var minimumWidths: [ObjectIdentifier: NSLayoutConstraint] = [:]

    func update(from model: FileTranslationModel, glossaries: GlossaryLibraryModel) {
        title.stringValue = model.url == nil ? "Translate a File" : model.title
        summary.stringValue = model.url == nil ? "Drop a file, or choose one." : model.summary
        summary.toolTip = model.summary
        summary.isHidden = summary.stringValue.isEmpty
        icon.image = model.url.flatMap { UTType(filenameExtension: $0.pathExtension) }.map { NSWorkspace.shared.icon(for: $0) }
            ?? NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        updateProviders(model)
        updateTargets(model)
        updateGlossaries(glossaries)
        let enabled = model.kind != nil
        for popUp in [providerPopUp, targetPopUp, glossaryPopUp] {
            popUp.isEnabled = enabled
            // The title, an item image if any, and the pop-up's own padding and arrows.
            let item = popUp.selectedItem
            let titleWidth = NSAttributedString(string: item?.title ?? "", attributes: [.font: popUp.font ?? .systemFont(ofSize: 13)])
                .size().width
            minimumWidths[ObjectIdentifier(popUp)]?.constant = ceil(titleWidth) + (item?.image == nil ? 0 : 20) + 44
        }
    }

    private func updateProviders(_ model: FileTranslationModel) {
        if shownProviders != model.providers {
            shownProviders = model.providers
            Self.setItems(of: providerPopUp, to: model.providers.map(\.name))
        }
        if let index = model.providers.firstIndex(where: { $0.id == model.providerID }) {
            providerPopUp.selectItem(at: index)
        }
    }

    private func updateTargets(_ model: FileTranslationModel) {
        var targets = LanguageCatalog.targets
        if !targets.contains(model.targetCode) {
            targets.insert(model.targetCode, at: 0)
        }
        if shownTargets != targets {
            shownTargets = targets
            Self.setItems(of: targetPopUp, to: targets.map(LanguageCatalog.name(of:)))
        }
        targetPopUp.selectItem(at: targets.firstIndex(of: model.targetCode) ?? 0)
    }

    private func updateGlossaries(_ glossaries: GlossaryLibraryModel) {
        let projects = glossaries.projects
        glossaryPopUp.isHidden = projects.isEmpty
        let ids = [nil] + projects.map(\.id)
        let titles = ["No Glossary"] + projects.map { $0.name.isEmpty ? "Untitled" : $0.name }
        if shownGlossaries != ids || glossaryPopUp.itemTitles != titles {
            shownGlossaries = ids
            Self.setItems(of: glossaryPopUp, to: titles)
            for (index, item) in glossaryPopUp.itemArray.enumerated() {
                item.image = NSImage(systemSymbolName: index == 0 ? "book.closed" : "character.book.closed", accessibilityDescription: nil)
            }
        }
        glossaryPopUp.selectItem(at: ids.firstIndex(of: glossaries.activeProjectID) ?? 0)
    }

    /// Fills a pop-up through its menu, because `addItems(withTitles:)` drops items whose title repeats.
    private static func setItems(of popUp: NSPopUpButton, to titles: [String]) {
        popUp.removeAllItems()
        for title in titles {
            popUp.menu?.addItem(withTitle: title, action: nil, keyEquivalent: "")
        }
    }

    @objc private func providerChosen() {
        let index = providerPopUp.indexOfSelectedItem
        guard shownProviders.indices.contains(index) else { return }
        actions.selectProvider(shownProviders[index].id)
    }

    @objc private func targetChosen() {
        let index = targetPopUp.indexOfSelectedItem
        guard shownTargets.indices.contains(index) else { return }
        actions.selectTarget(shownTargets[index])
    }

    @objc private func glossaryChosen() {
        let index = glossaryPopUp.indexOfSelectedItem
        guard shownGlossaries.indices.contains(index) else { return }
        actions.selectGlossary(shownGlossaries[index])
    }
}
