import AppKit
import SharedUI

/// The list's context menu and the toolbar's More menu, built each time they open from what they act on.
extension ActivityWindowController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        let processes = actionTargets
        guard !processes.isEmpty else {
            if menu === actionsMenu {
                menu.addItem(item("Activity Monitor Settings…", "gearshape") { [weak self] in self?.openSettings?() })
            }
            return
        }
        if menu === list.contextMenu {
            menu.addItem(item("Quit…", "xmark.octagon", key: "q", modifiers: [.command, .option]) { [weak self] in
                self?.quitSelection(force: false)
            })
            menu.addItem(item("Force Quit…", "xmark.octagon.fill") { [weak self] in self?.quitSelection(force: true) })
        }
        menu.addItem(signalMenu())
        menu.addItem(.separator())
        addProcessItems(to: menu, processes)
        menu.addItem(.separator())
        menu.addItem(copyMenu(processes))
        if menu === actionsMenu {
            menu.addItem(.separator())
            menu.addItem(item("Activity Monitor Settings…", "gearshape") { [weak self] in self?.openSettings?() })
        }
    }

    private func addProcessItems(to menu: NSMenu, _ processes: [ProcessMetrics]) {
        let single = processes.count == 1 ? processes.first : nil
        let sample = item("Sample Process…", "waveform.path.ecg") { [weak self] in self?.sampleSelection() }
        sample.isEnabled = single.map(Self.canSample) ?? false
        if let single, !Self.canSample(single) {
            sample.toolTip = "macOS lets Oriel sample only your own processes."
        }
        menu.addItem(sample)
        let reveal = item("Reveal in Finder", "folder") { [weak self] in
            if let single {
                self?.reveal(single)
            }
        }
        reveal.isEnabled = single.map { $0.path != nil } ?? false
        menu.addItem(reveal)
        menu.addItem(item("Show Details", "info.circle", key: "i") { [weak self] in self?.showInspector() })
        if let single, single.parentPID != single.pid, model.snapshot?.processes.contains(where: { $0.pid == single.parentPID }) == true {
            menu.addItem(item("Select Parent Process", "arrow.up.left") { [weak self] in self?.selectProcess(pid: single.parentPID) })
        }
    }

    private func signalMenu() -> NSMenuItem {
        let menu = NSMenu()
        for signal in ProcessSignal.allCases {
            menu.addItem(item(signal.title, nil) { [weak self] in self?.send(signal) })
        }
        let parent = NSMenuItem(title: "Send Signal", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: nil)
        parent.submenu = menu
        return parent
    }

    private func copyMenu(_ processes: [ProcessMetrics]) -> NSMenuItem {
        let menu = NSMenu()
        menu.addItem(item("Name", nil) { [weak self] in self?.copy(processes.map(\.name).joined(separator: "\n")) })
        menu.addItem(item("PID", nil) { [weak self] in self?.copy(processes.map { String($0.pid) }.joined(separator: "\n")) })
        let paths = processes.compactMap(\.path)
        let path = item("Path", nil) { [weak self] in self?.copy(paths.joined(separator: "\n")) }
        path.isEnabled = !paths.isEmpty
        menu.addItem(path)
        menu.addItem(item("Details", nil) { [weak self] in
            self?.copy(processes.map(Self.summaryText).joined(separator: "\n\n"))
        })
        let parent = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        parent.submenu = menu
        return parent
    }

    /// Key equivalents here only label the menu; the window handles the keys themselves.
    private func item(
        _ title: String,
        _ symbol: String?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        action: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenuItem {
        ActionMenuItem(title, symbol: symbol, key: key, modifiers: modifiers, handler: action)
    }
}
