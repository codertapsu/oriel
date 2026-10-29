import AppKit
import OrielCore
import os

/// What the panel's buttons, menus, drops and keys do to the library.
extension ColorPanelController {
    // MARK: Copying

    /// Copies the current color in `format`, and says so on its row.
    func copy(_ format: ColorFormat) {
        guard let color = model.current else {
            NSSound.beep()
            return
        }
        copier(ColorFormatter.string(format, for: color, uppercaseHex: model.uppercaseHex))
        content.colorTab.row(for: format)?.flashCopied()
        say("Copied \(ColorFormatter.title(format, for: color))")
    }

    /// ⌘C: the current color in the default format; on the Contrast tab, the ratio and the colors.
    func copyDefault() {
        switch content.selectedTab {
        case .color:
            copy(model.defaultFormat)
        case .palettes:
            guard let selected = selectedPaletteColor, let entry = model.library.paletteColor(selected)?.color else {
                copy(model.defaultFormat)
                return
            }
            copier(ColorFormatter.string(model.defaultFormat, for: entry.color, uppercaseHex: model.uppercaseHex))
            say("Copied \(entry.name ?? ColorFormatter.title(model.defaultFormat, for: entry.color))")
        case .contrast:
            copier(contrastSummary)
            say("Copied the contrast ratio")
        }
    }

    /// "4.47:1 — #777777 on #FFFFFF".
    var contrastSummary: String {
        let library = model.library
        let shown = WCAGContrast.shown(library.contrastText, on: library.contrastBackground)
        let ratio = WCAGContrast.ratioText(WCAGContrast.ratio(shown, library.contrastBackground))
        let text = library.contrastText.hex(uppercase: model.uppercaseHex, includesAlpha: !library.contrastText.isOpaque)
        return "\(ratio) — \(text) on \(library.contrastBackground.hex(uppercase: model.uppercaseHex))"
    }

    // MARK: Recent colors

    func selectRecent(at index: Int) {
        guard model.library.history.indices.contains(index) else { return }
        model.show(model.library.history[index])
    }

    func removeRecent(at index: Int) {
        guard let color = model.library.history[safe: index] else { return }
        model.change(undoMessage: "Removed \(color.hex(uppercase: model.uppercaseHex)) from Recent") { $0.removeFromHistory(at: index) }
    }

    func clearRecent() {
        model.change(undoMessage: "Cleared Recent colors") { $0.clearHistory() }
    }

    // MARK: Palettes

    @discardableResult
    func newPalette(with color: ColorValue?) -> UUID {
        var id = UUID()
        model.change { library in
            id = library.addPalette(colors: color.map { [$0] } ?? [])
        }
        content.show(.palettes)
        content.palettesTab.reveal(id)
        content.palettesTab.section(id)?.beginRenaming()
        return id
    }

    func addCurrentColor(to paletteID: UUID) {
        guard let color = model.current else {
            NSSound.beep()
            return
        }
        add(color, to: paletteID)
    }

    func add(_ color: ColorValue, to paletteID: UUID) {
        var added: UUID?
        model.change { added = $0.add(color, toPalette: paletteID) }
        selectedPaletteColor = added ?? selectedPaletteColor
        refresh()
        if let name = model.library.palette(paletteID)?.name {
            say("Added \(color.hex(uppercase: model.uppercaseHex)) to \(name)")
        }
    }

    func movePalette(_ id: UUID, by offset: Int) {
        guard let index = model.library.palettes.firstIndex(where: { $0.id == id }) else { return }
        model.change { $0.movePalette(id, to: index + offset) }
    }

    func deletePalette(_ id: UUID) {
        guard let palette = model.library.palette(id) else { return }
        model.change(undoMessage: "Deleted “\(palette.name)”") { $0.deletePalette(id) }
    }

    func selectPaletteColor(_ id: UUID) {
        selectedPaletteColor = id
        if let entry = model.library.paletteColor(id)?.color {
            model.show(entry.color)
        }
        refresh()
    }

    func renameSelectedColor(_ name: String) {
        guard let id = selectedPaletteColor else { return }
        model.change { $0.renameColor(id, to: name) }
    }

    func removeSelectedColor() {
        guard let id = selectedPaletteColor else {
            NSSound.beep()
            return
        }
        removePaletteColor(id)
    }

    func removePaletteColor(_ id: UUID) {
        guard let (paletteID, entry) = model.library.paletteColor(id), let palette = model.library.palette(paletteID) else { return }
        let what = entry.name ?? entry.color.hex(uppercase: model.uppercaseHex)
        model.change(undoMessage: "Removed \(what) from “\(palette.name)”") { $0.removeColor(id) }
    }

    /// A swatch dropped into a palette: an entry of this panel moves, any other color is added where it landed.
    func drop(_ drop: ColorDrop, into paletteID: UUID, at insertionIndex: Int) -> Bool {
        switch drop {
        case let .paletteColor(id, color):
            guard let (sourceID, _) = model.library.paletteColor(id) else {
                insert(color, into: paletteID, at: insertionIndex)
                return true
            }
            var destination = insertionIndex
            // Within one palette, the gap index counts the dragged color itself while it is still in place.
            let from = model.library.palette(paletteID)?.colors.firstIndex { $0.id == id }
            if sourceID == paletteID, let from, from < insertionIndex {
                destination -= 1
            }
            model.change { $0.moveColor(id, toPalette: paletteID, at: destination) }
        case let .color(color):
            insert(color, into: paletteID, at: insertionIndex)
        }
        return true
    }

    private func insert(_ color: ColorValue, into paletteID: UUID, at index: Int) {
        var added: UUID?
        model.change { added = $0.add(color, toPalette: paletteID, at: index) }
        selectedPaletteColor = added ?? selectedPaletteColor
        refresh()
    }

    // MARK: Contrast

    func useForContrast(_ color: ColorValue, asText: Bool) {
        model.change { library in
            if asText {
                library.contrastText = color
            } else {
                library.contrastBackground = color
            }
        }
        content.show(.contrast)
    }

    // MARK: Export

    /// Asks where to save, then writes the palette off the main thread.
    func export(_ paletteID: UUID, as format: PaletteExportFormat) {
        guard let palette = model.library.palette(paletteID) else { return }
        let save = NSSavePanel()
        save.title = "Export “\(palette.name)”"
        save.nameFieldStringValue = "\(palette.name).\(format.fileExtension)"
        save.allowedContentTypes = [format.contentType]
        save.canCreateDirectories = true
        NSApp.activate()
        guard save.runModal() == .OK, let url = save.url else { return }
        let uppercase = model.uppercaseHex
        let log = Log.logger("color-picker")
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    switch format {
                    case .json: try PaletteExport.json(palette, uppercaseHex: uppercase).write(to: url, options: .atomic)
                    case .css: try Data(PaletteExport.css(palette, uppercaseHex: uppercase).utf8).write(to: url, options: .atomic)
                    case .colorList: try ColorListWriter.write(palette, to: url, uppercaseHex: uppercase)
                    }
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if let result {
                log.error("A palette export failed: \(result, privacy: .public)")
                say("Could not export: \(result)")
            } else {
                say("Exported \(url.lastPathComponent)")
            }
        }
    }
}
