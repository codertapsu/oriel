import Hotkeys
import OrielCore
import SharedUI
import SwiftUI

/// Global shortcuts for capture, recording, translation and every tool that is on (Carbon hot keys, no permission
/// needed). The window switcher's own shortcuts are in its pane.
struct ShortcutsPane: View {
    let controller: AppController

    var body: some View {
        Form {
            Section {
                ForEach(appRows) { row in
                    rowView(row)
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Click a field, then type the combination. Esc cancels, Delete clears. ⚠︎ means another app already uses it.")
            }
            let modules = controller.registry.enabledModulesWithCommands
            ForEach(modules.indices, id: \.self) { index in
                Section(modules[index].displayName) {
                    ForEach(modules[index].commands.map(ShortcutRow.init)) { row in
                        rowView(row)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// The app's own actions, then the commands of capture, recording, translation and the editor.
    private var appRows: [ShortcutRow] {
        AppAction.shortcutActions.map(ShortcutRow.init) + controller.hub.commands.map(ShortcutRow.init)
    }

    private var allRows: [ShortcutRow] {
        appRows + controller.registry.commands.map(ShortcutRow.init)
    }

    private func rowView(_ row: ShortcutRow) -> some View {
        LabeledContent {
            HStack {
                ShortcutRecorder(combo: controller.settings.binding(row.key), inUse: inUse(except: row))
                    .frame(width: 160, height: 24)
                if let error = controller.shortcutErrors[row.id] {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help(error)
                }
                Button("Default") { controller.settings.reset(row.key) }
                    .disabled(controller.settings[row.key] == row.key.defaultValue)
            }
        } label: {
            HStack(spacing: 6) {
                Text(row.title)
                if let feature = row.proFeature {
                    ProBadge(feature)
                }
            }
        }
    }

    private func inUse(except row: ShortcutRow) -> [KeyCombo: String] {
        var used: [KeyCombo: String] = [:]
        for other in allRows where other.id != row.id {
            if let combo = controller.settings[other.key] {
                used[combo] = other.title
            }
        }
        return used
    }
}

/// One line of the pane: an app action or a command.
private struct ShortcutRow: Identifiable {
    let id: String
    let title: String
    let key: SettingKey<KeyCombo?>
    let proFeature: ProFeature?

    init(_ action: AppAction) {
        id = action.rawValue
        title = action.title
        key = action.shortcutKey
        proFeature = action.proFeature
    }

    init(_ command: ToolCommand) {
        id = command.id
        title = command.title
        key = command.shortcutKey
        proFeature = command.proFeature
    }
}
