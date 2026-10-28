import AppKit
import SharedUI

/// The overlay's toolbar (PLAN §10.5): provider pop-up (⌘1…⌘9), target language, swap, copy all, AI Vision, side panel,
/// status, offline badge and close. Glass, or opaque under the accessibility display options.
@MainActor
final class TranslationToolbar: NSView {
    struct Actions {
        var selectProvider: @MainActor (ProviderID) -> Void
        var selectTarget: @MainActor (String) -> Void
        var swap: @MainActor () -> Void
        var copyAll: @MainActor () -> Void
        var aiVision: @MainActor () -> Void
        var toggleSidePanel: @MainActor () -> Void
        var close: @MainActor () -> Void
    }

    private let actions: Actions
    private let providerPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let targetPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let status = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let offlineBadge = NSImageView()
    private var swapButton: HUDButton?
    private var visionButton: HUDButton?
    private var shownProviders: [TranslationSessionModel.ProviderChoice] = []
    private var shownTargets: [String] = []

    init(actions: Actions) {
        self.actions = actions
        super.init(frame: .zero)
        build()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        let background = Material.make(cornerRadius: 14)
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        providerPopUp.target = self
        providerPopUp.action = #selector(providerChosen)
        providerPopUp.controlSize = .small
        providerPopUp.toolTip = "Translation provider (⌘1…⌘9)"
        targetPopUp.target = self
        targetPopUp.action = #selector(targetChosen)
        targetPopUp.controlSize = .small
        targetPopUp.toolTip = "Translate into"

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.widthAnchor.constraint(lessThanOrEqualToConstant: 240).isActive = true

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        offlineBadge.image = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "Offline")
        offlineBadge.contentTintColor = .systemOrange
        offlineBadge.toolTip = ProviderAvailability.offline.message

        let swap = HUDButton(symbol: "arrow.left.arrow.right", label: "Swap languages") { [actions] in actions.swap() }
        let vision = HUDButton(symbol: "eye", label: "AI Vision: send the image to the model") { [actions] in actions.aiVision() }
        swapButton = swap
        visionButton = vision
        let stack = NSStackView(views: [
            providerPopUp, targetPopUp, swap,
            HUDButton(symbol: "doc.on.doc", label: "Copy all translations") { [actions] in actions.copyAll() },
            vision,
            HUDButton(symbol: "sidebar.right", label: "Show source and translation side by side") { [actions] in
                actions.toggleSidePanel()
            },
            spinner, offlineBadge, status,
            HUDButton(symbol: "xmark", label: "Close (Esc)") { [actions] in actions.close() },
        ])
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
        ])
    }

    func update(from model: TranslationSessionModel) {
        if shownProviders != model.providers {
            shownProviders = model.providers
            providerPopUp.removeAllItems()
            for (index, provider) in model.providers.enumerated() {
                providerPopUp.addItem(withTitle: provider.name)
                if index < 9, let item = providerPopUp.lastItem {
                    // Shown in the menu; the overlay handles the keys itself.
                    item.keyEquivalent = String(index + 1)
                    item.keyEquivalentModifierMask = .command
                }
            }
        }
        if let index = model.providers.firstIndex(where: { $0.id == model.providerID }) {
            providerPopUp.selectItem(at: index)
        }
        var targets = LanguageCatalog.targets
        if !targets.contains(model.targetCode) {
            targets.insert(model.targetCode, at: 0)
        }
        if shownTargets != targets {
            shownTargets = targets
            targetPopUp.removeAllItems()
            targetPopUp.addItems(withTitles: targets.map(LanguageCatalog.name(of:)))
        }
        targetPopUp.selectItem(at: targets.firstIndex(of: model.targetCode) ?? 0)
        status.stringValue = model.statusText
        status.toolTip = model.statusText
        if model.isBusy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        offlineBadge.isHidden = !model.isOffline
        visionButton?.isHidden = !(model.provider?.capabilities.contains(.imageInput) ?? false)
        swapButton?.isEnabled = model.sourceLanguage.map { !LanguageCatalog.isSameLanguage($0, model.targetLanguage) } ?? false
        visionButton?.contentTintColor = model.usesImageInput ? .controlAccentColor : .labelColor
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
}
