import OrielCore
import SwiftUI

/// Settings → Disk Space Analyzer: how scans count and what they skip, Old Files, the confirmations, and Full Disk
/// Access.
struct DiskSettingsView: View {
    let model: DiskSettingsModel
    @State private var confirmsForget = false

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Disk Space Analyzer") {
                if !model.isActive {
                    Text("Disk Space Analyzer is off. Turn it on in General → Tools.").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Open the analyzer") {
                    Button("Open Disk Space Analyzer") { model.openAnalyzer() }
                        .disabled(!model.isActive)
                }
                Text("It has no shortcut until you set one in Settings → Shortcuts; oriel://disk opens it too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            scanning(settings)
            Section("Exclusions") {
                ExclusionsEditor(model: model, entries: settings.binding(DiskSettings.exclusions))
                Text("""
                A folder added here is skipped with everything inside it; a name is skipped wherever a folder has it. \
                Excluded folders are listed with no size.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            safety(settings)
            administrator(settings)
            access
        }
        .formStyle(.grouped)
        .confirmationDialog("Forget all remembered scans?", isPresented: $confirmsForget) {
            Button("Forget Scans", role: .destructive) { model.forgetAllScans() }
        } message: {
            Text("What grew since a scan can then be shown only from the next one on.")
        }
    }

    private func scanning(_ settings: SettingsStore) -> some View {
        Section("Scanning") {
            Picker("Count files one by one from", selection: settings.binding(DiskSettings.smallFileThreshold)) {
                ForEach(DiskSettings.thresholdChoices, id: \.self) { bytes in
                    Text(DiskFormat.bytes(Int64(bytes))).tag(bytes)
                }
            }
            Text("Smaller files are counted together per folder, exactly, which keeps a scan of millions of files small.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Include hidden files and folders", isOn: settings.binding(DiskSettings.includesHiddenFiles))
            Text("Hidden folders such as ~/.npm or ~/.cache are often among the largest.").font(.caption).foregroundStyle(.secondary)
            Toggle("Count macOS's own files one by one", isOn: settings.binding(DiskSettings.countsMacOSFiles))
            Text("""
            A scan of the startup disk also reads the sealed system volume and the volumes macOS keeps for itself (Preboot, \
            VM with the swap files, Update), in a folder named macOS. Off, they are one block and scans are a little faster.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            Toggle("Go into other volumes inside the folder", isOn: settings.binding(DiskSettings.crossesVolumes))
            Text("Only local volumes you mounted are entered; network shares and the disk images macOS mounts for itself never are.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Keep the scan up to date while the window is open", isOn: settings.binding(DiskSettings.watchesChanges))
            Toggle("Remember scans to show what grew", isOn: settings.binding(DiskSettings.remembersScans))
            Button("Forget Remembered Scans…") { confirmsForget = true }
            Toggle("Ask Spotlight when files were last opened", isOn: settings.binding(DiskSettings.usesSpotlightDates))
            Text("Old Files then trusts “last opened” over access dates, which APFS updates only now and then.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func safety(_ settings: SettingsStore) -> some View {
        Section("Safety") {
            Toggle("Ask before moving items to the Trash", isOn: settings.binding(DiskSettings.confirmsTrash))
            Text("""
            Deleting immediately always asks twice. macOS itself, the tops of volumes, your home folder and its own \
            folders, the Library folders apps rely on, the inside of apps, and Oriel are never removed or moved.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func administrator(_ settings: SettingsStore) -> some View {
        Section("Read as Administrator") {
            Text(model.helperExplanation).font(.caption).foregroundStyle(.secondary)
            switch model.helperStatus {
            case .unavailable:
                EmptyView()
            case .notInstalled:
                Button("Install Helper…") { model.installHelper() }
            case .needsApproval:
                Button("Open Login Items") { model.openLoginItems() }
                Button("Remove Helper") { model.removeHelper() }
            case .allowed:
                Toggle("Read them in every scan", isOn: settings.binding(DiskSettings.readsAsAdministrator))
                Button("Remove Helper") { model.removeHelper() }
            }
        }
        .task {
            model.refreshHelperStatus()
            // Coming back from System Settings: show whether the helper is allowed now.
            let activations = NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification).map { _ in () }
            for await _ in activations {
                model.refreshHelperStatus()
            }
        }
    }

    private var access: some View {
        Section("Full Disk Access") {
            Text("""
            Without it, macOS keeps your private data from Oriel (Mail, Messages, Safari, other apps' data), and a scan \
            counts those folders as unreadable. Granting it is optional; quit and reopen Oriel afterwards. It does not open \
            folders only macOS or another user may open: Read as Administrator in the window reads those. Folders System \
            Integrity Protection guards stay closed to every app.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("Open Full Disk Access Settings") { model.openFullDiskAccess() }
        }
    }
}
