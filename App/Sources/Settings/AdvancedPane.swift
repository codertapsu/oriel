import OrielCore
import SwiftUI

/// Diagnostics, the command-line tool, the shared configuration and uninstall (PLAN §3.2, §7.1.8, §7.7.5, §15.8).
struct AdvancedPane: View {
    let controller: AppController
    @State private var capabilities: Capabilities?
    @State private var installed = CLIInstaller.installedLocations
    @State private var message: String?

    var body: some View {
        Form {
            Section("Diagnostics") {
                if let capabilities {
                    LabeledContent("Architecture", value: capabilities.arch + (capabilities.isRosetta ? " (Rosetta)" : ""))
                    LabeledContent("Apple silicon", value: capabilities.isAppleSiliconHardware ? "yes" : "no")
                    LabeledContent("Apple Intelligence", value: capabilities.appleIntelligence)
                    LabeledContent("Translation packs", value: capabilities.translationPacks)
                    let found = capabilities.privateSymbols.values.filter(\.self).count
                    LabeledContent("Private symbols", value: "\(found) of \(capabilities.privateSymbols.count)")
                    ForEach(capabilities.permissions.keys.sorted(), id: \.self) { name in
                        LabeledContent(name, value: capabilities.permissions[name] ?? "")
                    }
                    Button("Copy as JSON") { copy(capabilities) }
                } else {
                    ProgressView()
                }
            }
            Section {
                ForEach([CLIInstaller.Location.user, .system], id: \.self) { location in
                    LabeledContent(location.link.path) {
                        if installed.contains(location) {
                            Button("Remove") { change { try CLIInstaller.uninstall(location) } }
                        } else {
                            Button(location == .system ? "Install (asks for your password)" : "Install") {
                                change { try CLIInstaller.install(location) }
                            }
                        }
                    }
                }
            } header: {
                Text("Command-line tool")
            } footer: {
                Text("Links `oriel` to the copy inside this app. ~/.local/bin must be on your PATH.")
            }
            Section("Shared configuration") {
                Button("Reload shared configuration") {
                    Task { message = await controller.bootstrapImporter.importAvailable() ?? "No bootstrap.json and no BootstrapURL." }
                }
                if let date = controller.settings[AppSettings.lastBootstrapImport] {
                    Text("Last imported \(date.formatted(date: .abbreviated, time: .shortened)).").font(.caption)
                }
            }
            Section {
                Button("Uninstall Oriel…", role: .destructive) {
                    Uninstaller.run(
                        settings: controller.settings,
                        keychain: controller.keychain,
                        keychainServices: controller.hub.keychainServices
                    )
                }
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { capabilities = await controller.capabilities() }
    }

    private func change(_ action: () throws -> Void) {
        do {
            try action()
            message = nil
        } catch {
            message = error.localizedDescription
        }
        installed = CLIInstaller.installedLocations
    }

    private func copy(_ capabilities: Capabilities) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(capabilities), let text = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}
