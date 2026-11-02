import AppKit
import OrielCore
import SharedUI

/// The Color Picker panel: a floating, non-activating panel, so the app the user is working in stays active. It
/// becomes key when it opens (the number keys and ⌘C work at once) and otherwise only when a field needs typing; a
/// click on a format or a swatch works without taking the keyboard from the other app. It stays open, above other
/// windows, until it is closed with Esc, ⌘W, its close button or the shortcut, and it remembers where it was put.
final class ColorPanelController: NSObject {
    /// Which color the loupe sets.
    enum PickTarget {
        case current
        case contrastText
        case contrastBackground
    }

    static let frameName = "OrielColorPickerPanel"

    let model: ColorPickerModel
    let content = ColorPanelView(frame: CGRect(origin: .zero, size: ColorPanelView.size))
    let panel = FloatingPanel(contentRect: CGRect(origin: .zero, size: ColorPanelView.size), level: .floating)
    /// Starts the system loupe for one of the colors; set by the module.
    var pick: ((PickTarget) -> Void)?
    /// Opens Settings at Color Picker.
    var openSettings: (() -> Void)?
    /// Every copy goes through here: the general pasteboard, by default, announced to Clipboard History.
    var copier: (String) -> Void = { Pasteboard.copy($0) }
    /// The palette color selected in the Palettes tab.
    var selectedPaletteColor: UUID?
    var statusTask: Task<Void, Never>?

    init(model: ColorPickerModel) {
        self.model = model
        super.init()
        panel.allowsKey = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.contentView = content
        panel.contentMinSize = ColorPanelView.size
        panel.contentMaxSize = ColorPanelView.size
        panel.setAccessibilityLabel("Color Picker")
        panel.setAccessibilityTitle("Color Picker")
        connectViews()
        refresh()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var isKey: Bool {
        panel.isKeyWindow
    }

    /// Shows the panel, at `tab` when given, and takes the keyboard so the number keys and ⌘C work at once.
    func show(tab: ColorPanelTab? = nil) {
        if let tab {
            select(tab)
        }
        refresh()
        if !panel.isVisible {
            // Named here rather than at init, so that a panel that is never shown writes no frame to the defaults.
            if panel.frameAutosaveName.isEmpty {
                panel.setFrameAutosaveName(Self.frameName)
            }
            placeIfNeeded()
        }
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(content)
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        model.forgetUndo()
        statusTask?.cancel()
        content.showStatus(nil, undo: false)
    }

    /// Shows the model as it is now.
    func refresh() {
        let library = model.library
        let uppercase = model.uppercaseHex
        content.colorTab.show(model.current, defaultFormat: model.defaultFormat, uppercaseHex: uppercase)
        content.colorTab.recent.show(library.history, selected: model.current, uppercaseHex: uppercase)
        if let selected = selectedPaletteColor, library.paletteColor(selected) == nil {
            selectedPaletteColor = nil
        }
        content.palettesTab.show(library.palettes, selectedColor: selectedPaletteColor, uppercaseHex: uppercase)
        content.contrastTab.show(text: library.contrastText, background: library.contrastBackground, uppercaseHex: uppercase)
        if let undo = model.undoState {
            statusTask?.cancel()
            content.showStatus(undo.message, undo: true)
        } else if !content.undoButton.isHidden {
            content.showStatus(nil, undo: false)
        }
    }

    /// A line in the footer for a few seconds; Undo stays available meanwhile, and its line comes back afterwards.
    func say(_ text: String) {
        statusTask?.cancel()
        content.showStatus(text, undo: model.undoState != nil)
        statusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            content.showStatus(model.undoState?.message, undo: model.undoState != nil)
        }
    }

    // MARK: Placement

    /// The first time, at the right of the screen under the pointer, like an inspector; afterwards where the user left
    /// it, as long as that is still on a screen.
    private func placeIfNeeded() {
        let frame = panel.frame
        if frame.origin != .zero, NSScreen.screens.contains(where: { $0.visibleFrame.intersection(frame).width > 80 }) {
            return
        }
        guard let screen = ScreenLocator.screenUnderMouse else { return }
        let visible = screen.visibleFrame
        let size = ColorPanelView.size
        let origin = CGPoint(x: visible.maxX - size.width - 24, y: (visible.midY - size.height / 2).rounded())
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    private func connectViews() {
        content.tabs.target = self
        content.tabs.action = #selector(tabChanged)
        content.onKeyDown = { [weak self] event in self?.keyDown(event) ?? false }
        content.onKeyEquivalent = { [weak self] event in self?.keyEquivalent(event) ?? false }
        content.onCancel = { [weak self] in self?.close() }
        for (button, action) in [
            (content.pickButton, #selector(pickClicked)),
            (content.closeButton, #selector(closeClicked)),
            (content.undoButton, #selector(undoClicked)),
            (content.palettesTab.newPaletteButton, #selector(newPaletteClicked)),
            (content.contrastTab.swapButton, #selector(swapClicked)),
        ] {
            button.target = self
            button.action = action
        }
        connectColorTab()
        connectPalettesTab()
        connectContrastTab()
    }

    private func connectColorTab() {
        let tab = content.colorTab
        tab.swatch.onColor = { [weak self] color in self?.model.pick(color) }
        for row in tab.rows {
            row.onCopy = { [weak self] format in self?.copy(format) }
        }
        tab.recent.onSelect = { [weak self] index in self?.selectRecent(at: index) }
        tab.recent.makeMenu = { [weak self] index in self?.recentMenu(for: index) }
        tab.addToPaletteButton.menu?.delegate = self
        tab.contrastButton.menu?.delegate = self
    }

    private func connectPalettesTab() {
        let tab = content.palettesTab
        tab.configureSection = { [weak self] section in self?.connect(section) }
        tab.detail.onRename = { [weak self] name in self?.renameSelectedColor(name) }
        tab.detail.onRemove = { [weak self] in self?.removeSelectedColor() }
    }

    private func connectContrastTab() {
        let tab = content.contrastTab
        tab.textRow.onColor = { [weak self] color in self?.model.change { $0.contrastText = color } }
        tab.backgroundRow.onColor = { [weak self] color in self?.model.change { $0.contrastBackground = color } }
        tab.textRow.onPick = { [weak self] in self?.pick?(.contrastText) }
        tab.backgroundRow.onPick = { [weak self] in self?.pick?(.contrastBackground) }
    }

    private func connect(_ section: PaletteSectionView) {
        let id = section.paletteID
        section.onRename = { [weak self] name in self?.model.change { $0.renamePalette(id, to: name) } }
        section.makeMenu = { [weak self] in self?.paletteMenu(for: id) ?? NSMenu() }
        section.grid.onAdd = { [weak self] in self?.addCurrentColor(to: id) }
        section.grid.onSelect = { [weak self] colorID in self?.selectPaletteColor(colorID) }
        section.grid.makeMenu = { [weak self] colorID in self?.paletteColorMenu(for: colorID) }
        section.grid.onDrop = { [weak self] drop, index in self?.drop(drop, into: id, at: index) ?? false }
    }

    // MARK: Buttons

    @objc private func tabChanged() {
        select(content.selectedTab)
        panel.makeFirstResponder(content)
    }

    /// Shows `tab`; Palettes and Contrast need Oriel Pro, and while it is locked the Color tab stays (PLAN §19).
    func select(_ tab: ColorPanelTab) {
        let feature: ProFeature? = switch tab {
        case .color: nil
        case .palettes: .palettes
        case .contrast: .contrastChecker
        }
        guard let feature, !ProAccess.shared.check(feature) else {
            content.show(tab)
            return
        }
        content.show(.color)
    }

    @objc private func pickClicked() {
        pick?(.current)
    }

    @objc private func closeClicked() {
        close()
    }

    @objc private func undoClicked() {
        model.undo()
    }

    @objc private func newPaletteClicked() {
        newPalette(with: nil)
    }

    @objc private func swapClicked() {
        model.change { $0.swapContrastColors() }
    }
}
