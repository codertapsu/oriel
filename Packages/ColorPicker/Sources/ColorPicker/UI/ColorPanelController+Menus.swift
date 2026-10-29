import AppKit
import SharedUI

/// The panel's menus: the Add to Palette and Check Contrast buttons, a recent color's and a palette color's context
/// menu, and a palette's ⋯ menu. Each is built when it opens, from the library as it is then.
extension ColorPanelController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let color = model.current else { return }
        if menu === content.colorTab.addToPaletteButton.menu {
            fill(menu, title: "Add to Palette", with: addToPaletteItems(for: color))
        } else if menu === content.colorTab.contrastButton.menu {
            fill(menu, title: "Check Contrast", with: contrastItems(for: color))
        }
    }

    /// A pull-down button shows its first item as its title, so that one stays.
    private func fill(_ menu: NSMenu, title: String, with items: [NSMenuItem]) {
        let first = menu.items.first
        menu.removeAllItems()
        if let first {
            menu.addItem(first)
        }
        items.forEach(menu.addItem)
    }

    // MARK: Pieces

    func addToPaletteItems(for color: ColorValue) -> [NSMenuItem] {
        var items: [NSMenuItem] = model.library.palettes.map { palette in
            let item = ActionMenuItem(palette.name, symbol: "swatchpalette") { [weak self] in self?.add(color, to: palette.id) }
            let already = palette.colors.contains { $0.color.isSameColor(as: color) }
            item.state = already ? .on : .off
            return item
        }
        if !items.isEmpty {
            items.append(.separator())
        }
        items.append(ActionMenuItem("New Palette with This Color", symbol: "plus") { [weak self] in
            self?.newPalette(with: color)
        })
        return items
    }

    func contrastItems(for color: ColorValue) -> [NSMenuItem] {
        [
            ActionMenuItem("Use as Text Color", symbol: "textformat") { [weak self] in self?.useForContrast(color, asText: true) },
            ActionMenuItem("Use as Background Color", symbol: "square.fill") { [weak self] in
                self?.useForContrast(color, asText: false)
            },
        ]
    }

    private func copyItem(for color: ColorValue) -> NSMenuItem {
        let format = model.defaultFormat
        return ActionMenuItem("Copy \(ColorFormatter.title(format, for: color))", symbol: "doc.on.doc") { [weak self] in
            guard let self else { return }
            copier(ColorFormatter.string(format, for: color, uppercaseHex: model.uppercaseHex))
            say("Copied \(ColorFormatter.string(.hex, for: color, uppercaseHex: model.uppercaseHex))")
        }
    }

    // MARK: Context menus

    func recentMenu(for index: Int) -> NSMenu? {
        guard let color = model.library.history[safe: index] else { return nil }
        let menu = NSMenu()
        menu.addItem(copyItem(for: color))
        contrastItems(for: color).forEach(menu.addItem)
        let palettes = NSMenuItem(title: "Add to Palette", action: nil, keyEquivalent: "")
        palettes.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        let submenu = NSMenu()
        addToPaletteItems(for: color).forEach(submenu.addItem)
        palettes.submenu = submenu
        menu.addItem(palettes)
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Remove from Recent", symbol: "minus.circle") { [weak self] in self?.removeRecent(at: index) })
        menu.addItem(ActionMenuItem("Clear Recent Colors", symbol: "trash") { [weak self] in self?.clearRecent() })
        return menu
    }

    func paletteColorMenu(for id: UUID) -> NSMenu? {
        guard let entry = model.library.paletteColor(id)?.color else { return nil }
        let menu = NSMenu()
        menu.addItem(copyItem(for: entry.color))
        contrastItems(for: entry.color).forEach(menu.addItem)
        menu.addItem(ActionMenuItem("Name…", symbol: "character.cursor.ibeam") { [weak self] in
            guard let self else { return }
            selectPaletteColor(id)
            content.palettesTab.detail.beginNaming()
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Remove from Palette", symbol: "trash") { [weak self] in self?.removePaletteColor(id) })
        return menu
    }

    func paletteMenu(for id: UUID) -> NSMenu {
        let menu = NSMenu()
        let palettes = model.library.palettes
        guard let index = palettes.firstIndex(where: { $0.id == id }) else { return menu }
        let add = ActionMenuItem("Add Current Color", symbol: "plus") { [weak self] in self?.addCurrentColor(to: id) }
        add.isEnabled = model.current != nil
        menu.autoenablesItems = false
        menu.addItem(add)
        menu.addItem(ActionMenuItem("Rename", symbol: "pencil") { [weak self] in
            self?.content.palettesTab.section(id)?.beginRenaming()
        })
        menu.addItem(.separator())
        let up = ActionMenuItem("Move Up", symbol: "arrow.up") { [weak self] in self?.movePalette(id, by: -1) }
        up.isEnabled = index > 0
        let down = ActionMenuItem("Move Down", symbol: "arrow.down") { [weak self] in self?.movePalette(id, by: 1) }
        down.isEnabled = index < palettes.count - 1
        menu.addItem(up)
        menu.addItem(down)
        menu.addItem(.separator())
        for format in PaletteExportFormat.allCases {
            let item = ActionMenuItem("Export as \(format.title)…", symbol: "square.and.arrow.up") { [weak self] in
                self?.export(id, as: format)
            }
            item.isEnabled = !palettes[index].colors.isEmpty
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Delete Palette", symbol: "trash") { [weak self] in self?.deletePalette(id) })
        return menu
    }
}
