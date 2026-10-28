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
            Section("Permissions") {
                Button("Show the permissions guide…") { controller.showOnboarding() }
            }
        }
        .formStyle(.grouped)
    }
}
