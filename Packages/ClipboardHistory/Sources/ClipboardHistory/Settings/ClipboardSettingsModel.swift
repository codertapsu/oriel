import Foundation
import Observation
import OrielCore

/// The live numbers and the actions of Settings → Clipboard History.
@Observable
final class ClipboardSettingsModel {
    private(set) var itemCount = 0
    private(set) var pinnedCount = 0
    private(set) var diskBytes = 0
    private(set) var access = ClipboardAccess.current
    /// Whether the pane is on screen; the counts are read only then.
    @ObservationIgnored var isShown = false
    @ObservationIgnored private weak var module: ClipboardHistoryModule?
    @ObservationIgnored private var refreshing: Task<Void, Never>?

    init(module: ClipboardHistoryModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    var isActive: Bool {
        module?.isActive ?? false
    }

    var failure: String? {
        module?.failure
    }

    var shortcut: String? {
        module?.shortcutDescription
    }

    /// Reads the counts and the size again while the pane shows, one read at a time.
    func refresh() {
        let current = ClipboardAccess.current
        if current != access {
            access = current
        }
        guard isShown else { return }
        refreshing?.cancel()
        let store = module?.store
        refreshing = Task {
            let index = await store?.index()
            let bytes = await store?.diskUsage() ?? 0
            guard !Task.isCancelled else { return }
            itemCount = index?.count ?? 0
            pinnedCount = index?.pinned.count ?? 0
            diskBytes = bytes
        }
    }

    func clear(includingPinned: Bool) {
        guard let store = module?.store else { return }
        Task {
            if let deletion = try? await store.removeAll(includingPinned: includingPinned), !deletion.isEmpty {
                await store.emptyTrash()
            }
            refresh()
        }
    }

    func openPasteboardSettings() {
        module?.openPasteboardSettings()
    }
}
