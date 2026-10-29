import OrielCore
import SwiftUI

struct GeneralPane: View {
    let controller: AppController
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var switcherOn = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Oriel at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                            launchError = LaunchAtLogin.needsApproval ? "Allow Oriel in System Settings → General → Login Items." : nil
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.orange)
                }
            }
            if !controller.registry.all.isEmpty {
                Section {
                    ForEach(controller.registry.all.indices, id: \.self) { index in
                        let module = controller.registry.all[index]
                        let id = type(of: module).id
                        Toggle(module.displayName, isOn: Binding(
                            get: { controller.settings[AppSettings.enabledModules].contains(id.rawValue) },
                            set: { enabled in Task { await controller.registry.setEnabled(id, enabled) } }
                        ))
                    }
                } header: {
                    Text("Tools")
                } footer: {
                    Text("A tool that is off uses no memory, keyboard tap or observers.")
                }
            }
            Section {
                Toggle("Sync settings through iCloud", isOn: controller.settings.binding(AppSettings.syncSettings))
                    .disabled(controller.sync.method == nil && !controller.settings[AppSettings.syncSettings])
                if controller.settings[AppSettings.syncSettings] {
                    HStack {
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Sync Now") { controller.sync.syncNow() }
                            .disabled(controller.sync.status == .syncing || controller.sync.status == .unavailable)
                    }
                }
            } header: {
                Text("Sync")
            } footer: {
                Text(syncFooter)
            }
            Section("Permissions") {
                Button("Show the permissions guide…") { controller.showOnboarding() }
            }
        }
        .formStyle(.grouped)
    }

    private var syncStatus: String {
        switch controller.sync.status {
        case .off: "Off"
        case .unavailable: "iCloud Drive is off. Turn it on in System Settings → Apple Account → iCloud."
        case .syncing: "Syncing…"
        case let .synced(date, otherMacs):
            syncedText(at: date.formatted(date: .omitted, time: .shortened), otherMacs: otherMacs)
        case let .failed(reason): "Not synced: \(reason)"
        }
    }

    private func syncedText(at time: String, otherMacs: Int) -> String {
        switch otherMacs {
        case 0: "Synced at \(time). No other Mac syncs yet."
        case 1: "Synced with 1 other Mac at \(time)."
        default: "Synced with \(otherMacs) other Macs at \(time)."
        }
    }

    private var syncFooter: String {
        let place = controller.sync.method == "iCloud Drive" ? " Oriel keeps them in an Oriel folder in iCloud Drive." : ""
        return "Shortcuts, tools and preferences follow you to your other Macs. Folders, upload destinations, passwords and "
            + "keys stay on each Mac.\(place)"
    }
}
