import Foundation
import OrielCore
import os

/// The Color Picker's live state, on the main actor: the library, the color the panel shows, and Undo for the last
/// thing deleted. Every change goes through `change(_:)`, which saves the library (`ColorStore`, off the main thread)
/// and tells the panel and the Settings pane.
final class ColorPickerModel {
    private(set) var library = ColorLibrary()
    /// The color the panel shows: the newest pick, or the one the user chose since.
    private(set) var current: ColorValue?
    /// The library as it was before the last deletion, and what to say about it; any other change forgets it.
    private(set) var undoState: (library: ColorLibrary, message: String)?
    /// Called after anything here changed.
    var onChange: (() -> Void)?

    let store: ColorStore
    private let settings: SettingsStore
    private var revision = 0
    private var saving: Task<Void, Never>?
    private let log = Log.logger("color-picker")

    init(store: ColorStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    var historyLimit: Int {
        settings[ColorPickerSettings.historySize]
    }

    var uppercaseHex: Bool {
        settings[ColorPickerSettings.uppercaseHex]
    }

    /// The format ⌘C and picking copy; a Pro format falls back to HEX while Oriel Pro is locked.
    var defaultFormat: ColorFormat {
        let format = settings[ColorPickerSettings.defaultFormat]
        return format.isPro && !ProAccess.shared.allows(.colorFormats) ? .hex : format
    }

    /// Reads the library from disk, once, when the module starts.
    func load() async {
        library = await store.load()
        library.trimHistory(to: historyLimit)
        current = current ?? library.history.first
        onChange?()
    }

    /// A color picked off the screen or typed in: it goes first in the history and becomes the current color.
    func pick(_ color: ColorValue) {
        current = color
        change { $0.record(color, limit: historyLimit) }
    }

    /// Shows a color without recording it, as when a palette color is clicked.
    func show(_ color: ColorValue) {
        guard current != color else { return }
        current = color
        onChange?()
    }

    /// Applies `body` to the library and saves the result. With `undoMessage`, Undo can bring back the library as it
    /// was before; without, Undo is forgotten, because it would also undo this change.
    func change(undoMessage: String? = nil, _ body: (inout ColorLibrary) -> Void) {
        let before = library
        body(&library)
        guard library != before else { return }
        undoState = undoMessage.map { (before, $0) }
        save()
        onChange?()
    }

    func undo() {
        guard let undoState else { return }
        library = undoState.library
        self.undoState = nil
        save()
        onChange?()
    }

    /// Forgets Undo, as when the panel closes.
    func forgetUndo() {
        guard undoState != nil else { return }
        undoState = nil
        onChange?()
    }

    /// The history size changed in Settings.
    func applyHistoryLimit() {
        change { $0.trimHistory(to: historyLimit) }
    }

    /// Waits for the saves already asked for, as before the module stops.
    func flush() async {
        await saving?.value
    }

    /// Each save waits for the one before, so they reach the disk in order.
    private func save() {
        revision += 1
        let snapshot = library
        let revision = revision
        let store = store
        let log = log
        let previous = saving
        saving = Task {
            await previous?.value
            do {
                try await store.save(snapshot, revision: revision)
            } catch {
                log.error("The color library could not be saved: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
