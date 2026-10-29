import OrielCore
import SwiftUI

/// Settings → Clipboard History: pasting, how much is kept and for how long, Paste from Other Apps, and the apps whose
/// copies are never kept.
struct ClipboardSettingsView: View {
    let model: ClipboardSettingsModel
    @State private var confirmsClear = false

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Clipboard History") {
                if let failure = model.failure {
                    Text(failure).font(.caption).foregroundStyle(.orange)
                } else if !model.isActive {
                    Text("Clipboard History is off. Turn it on in General → Tools.").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Open the history with") {
                    Text(model.shortcut ?? "No shortcut").foregroundStyle(.secondary)
                }
                Text("Change the shortcut in Settings → Shortcuts. In the history, Return pastes into the app you were in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Pause Clipboard History", isOn: settings.binding(ClipboardSettings.isPaused))
                Toggle("Paste text without formatting", isOn: settings.binding(ClipboardSettings.pastesPlainText))
                Text("⌥Return pastes the other way.").font(.caption).foregroundStyle(.secondary)
                Toggle("Remove items from the history after pasting them", isOn: settings.binding(ClipboardSettings.removesAfterPaste))
                Text("Pinned items always stay.").font(.caption).foregroundStyle(.secondary)
            }
            storage(settings)
            privacy(settings)
        }
        .formStyle(.grouped)
        .onAppear {
            model.isShown = true
            model.refresh()
        }
        .onDisappear { model.isShown = false }
        .confirmationDialog("Clear Clipboard History?", isPresented: $confirmsClear) {
            Button("Delete Unpinned Items", role: .destructive) { model.clear(includingPinned: false) }
            Button("Delete Everything, Pinned Items Too", role: .destructive) { model.clear(includingPinned: true) }
        } message: {
            Text("Deleted items cannot be brought back.")
        }
    }

    private func storage(_ settings: SettingsStore) -> some View {
        Section("Storage") {
            Picker("Keep up to", selection: settings.binding(ClipboardSettings.itemLimit)) {
                ForEach(ClipboardSettings.itemLimitChoices, id: \.self) { Text("\($0.formatted()) items").tag($0) }
            }
            Picker("Use at most", selection: settings.binding(ClipboardSettings.maxMegabytes)) {
                ForEach(ClipboardSettings.megabyteChoices, id: \.self) { megabytes in
                    Text(ClipboardFormat.bytes(megabytes * 1_000_000)).tag(megabytes)
                }
            }
            Picker("Keep items for", selection: settings.binding(ClipboardSettings.retentionDays)) {
                ForEach(ClipboardSettings.retentionChoices, id: \.self) { days in
                    Text(days == 0 ? "As long as there is room" : days == 1 ? "1 day" : "\(days) days").tag(days)
                }
            }
            LabeledContent("Kept now") {
                Text(keptNow).foregroundStyle(.secondary)
            }
            Text(Self.storageNote)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Clear History…") { confirmsClear = true }
                .disabled(model.itemCount == 0)
        }
    }

    private func privacy(_ settings: SettingsStore) -> some View {
        Section("Privacy") {
            LabeledContent("Paste from Other Apps") {
                HStack {
                    Text(accessText).foregroundStyle(model.access == .allowed ? .secondary : Color.orange)
                    if model.access == .asks || model.access == .denied {
                        Button("Open System Settings") { model.openPasteboardSettings() }
                    }
                }
            }
            Text(accessExplanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Copies that password managers mark as concealed or temporary are never kept.")
                .font(.caption)
                .foregroundStyle(.secondary)
            IgnoredAppsEditor(bundleIDs: settings.binding(ClipboardSettings.ignoredApps))
        }
    }

    private var accessText: String {
        switch model.access {
        case .allowed: "Allowed"
        case .notAsked: "Not asked yet"
        case .asks: "macOS asks each time"
        case .denied: "Denied"
        }
    }

    private var keptNow: String {
        "\(ClipboardFormat.count(model.itemCount, "item")), \(model.pinnedCount) pinned · \(ClipboardFormat.bytes(model.diskBytes))"
    }

    private static let storageNote = """
    None of these limits ever removes a pinned item. Everything is encrypted on this Mac, with a key in \
    your keychain.
    """

    private static let notAskedNote = """
    The first time you copy in another app, macOS asks whether Oriel may paste from it. Choose Allow, then set Oriel to \
    Allow in System Settings → Privacy & Security → Paste from Other Apps.
    """

    private static let blockedNote = """
    Until Oriel is set to Allow in System Settings → Privacy & Security → Paste from Other Apps, Clipboard History keeps \
    only Oriel's own copies, such as screenshots. Already allowed? Quit and reopen Oriel.
    """

    private var accessExplanation: String {
        switch model.access {
        case .allowed: "Clipboard History keeps what you copy in every app."
        case .notAsked: Self.notAskedNote
        case .asks, .denied: Self.blockedNote
        }
    }
}
