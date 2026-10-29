import Foundation

/// Everything the Color Picker remembers: the latest picks, newest first; the user's palettes, in their order; and the
/// two colors of the contrast checker. A value changed only through these methods, so the rules (the history's cap,
/// no color twice in a row of history or in one palette, unique default names) are tested without the panel, and Undo
/// is simply an earlier value.
nonisolated struct ColorLibrary: Hashable, Sendable {
    static let defaultHistoryLimit = 20

    private(set) var history: [ColorValue]
    private(set) var palettes: [Palette]
    var contrastText: ColorValue
    var contrastBackground: ColorValue

    init(
        history: [ColorValue] = [],
        palettes: [Palette] = [],
        contrastText: ColorValue = .black,
        contrastBackground: ColorValue = .white
    ) {
        self.history = history
        self.palettes = palettes
        self.contrastText = contrastText
        self.contrastBackground = contrastBackground
    }

    // MARK: History

    /// Puts `color` first; the same color further down moves up instead of appearing twice. Keeps at most `limit`.
    mutating func record(_ color: ColorValue, limit: Int) {
        history.removeAll { $0.isSameColor(as: color) }
        history.insert(color, at: 0)
        trimHistory(to: limit)
    }

    mutating func trimHistory(to limit: Int) {
        let limit = max(1, limit)
        if history.count > limit {
            history.removeLast(history.count - limit)
        }
    }

    mutating func removeFromHistory(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
    }

    mutating func clearHistory() {
        history = []
    }

    // MARK: Palettes

    func palette(_ id: UUID) -> Palette? {
        palettes.first { $0.id == id }
    }

    /// The palette holding a color, and the color.
    func paletteColor(_ colorID: UUID) -> (paletteID: UUID, color: PaletteColor)? {
        for palette in palettes {
            if let color = palette.colors.first(where: { $0.id == colorID }) {
                return (palette.id, color)
            }
        }
        return nil
    }

    /// "Palette 1", "Palette 2"…: the first such name not taken.
    var nextPaletteName: String {
        let taken = Set(palettes.map { $0.name.lowercased() })
        // With n palettes, one of the first n + 1 numbers is always free.
        let number = (1 ... palettes.count + 1).first { !taken.contains("palette \($0)") } ?? palettes.count + 1
        return "Palette \(number)"
    }

    /// Adds a palette at the end and returns its id. A blank name becomes the next default one.
    @discardableResult
    mutating func addPalette(named name: String? = nil, colors: [ColorValue] = []) -> UUID {
        let cleaned = Self.clean(name)
        var palette = Palette(name: cleaned ?? nextPaletteName)
        for color in colors where !palette.colors.contains(where: { $0.color.isSameColor(as: color) }) {
            palette.colors.append(PaletteColor(color: color))
        }
        palettes.append(palette)
        return palette.id
    }

    /// Renames a palette; a blank name leaves it as it was.
    mutating func renamePalette(_ id: UUID, to name: String) {
        guard let cleaned = Self.clean(name), let index = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[index].name = cleaned
    }

    /// Moves a palette so that it ends up at `destination` (clamped to the list).
    mutating func movePalette(_ id: UUID, to destination: Int) {
        guard let index = palettes.firstIndex(where: { $0.id == id }) else { return }
        let palette = palettes.remove(at: index)
        palettes.insert(palette, at: min(max(destination, 0), palettes.count))
    }

    mutating func deletePalette(_ id: UUID) {
        palettes.removeAll { $0.id == id }
    }

    /// Adds `color` to a palette, at `index` or at the end, and returns the entry. A color the palette already has is
    /// not added again; its entry is returned.
    @discardableResult
    mutating func add(_ color: ColorValue, toPalette id: UUID, at index: Int? = nil) -> UUID? {
        guard let paletteIndex = palettes.firstIndex(where: { $0.id == id }) else { return nil }
        if let existing = palettes[paletteIndex].colors.first(where: { $0.color.isSameColor(as: color) }) {
            return existing.id
        }
        let entry = PaletteColor(color: color)
        let colors = palettes[paletteIndex].colors
        palettes[paletteIndex].colors.insert(entry, at: min(max(index ?? colors.count, 0), colors.count))
        return entry.id
    }

    mutating func removeColor(_ colorID: UUID) {
        for index in palettes.indices {
            palettes[index].colors.removeAll { $0.id == colorID }
        }
    }

    /// Moves a color within its palette or into another one, so that it ends up at `destination` there. Moving a color
    /// into a palette that already has the same color merges the two.
    mutating func moveColor(_ colorID: UUID, toPalette id: UUID, at destination: Int) {
        guard let (sourceID, entry) = paletteColor(colorID), let target = palettes.firstIndex(where: { $0.id == id }) else { return }
        if sourceID != id, palettes[target].colors.contains(where: { $0.color.isSameColor(as: entry.color) }) {
            removeColor(colorID)
            return
        }
        removeColor(colorID)
        let count = palettes[target].colors.count
        palettes[target].colors.insert(entry, at: min(max(destination, 0), count))
    }

    /// Names a palette color; nil or a blank name removes the name.
    mutating func renameColor(_ colorID: UUID, to name: String?) {
        for paletteIndex in palettes.indices {
            if let colorIndex = palettes[paletteIndex].colors.firstIndex(where: { $0.id == colorID }) {
                palettes[paletteIndex].colors[colorIndex].name = Self.clean(name)
                return
            }
        }
    }

    // MARK: Contrast

    mutating func swapContrastColors() {
        swap(&contrastText, &contrastBackground)
    }

    /// Trimmed, and nil when nothing is left.
    private static func clean(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }
}
