import Hotkeys
import OrielCore
import SwiftUI

/// Global shortcuts for capture, recording and translation (Carbon hot keys, no permission needed).
/// The window switcher's own shortcuts are in its pane.
struct ShortcutsPane: View {
    let controller: AppController

    var body: some View {
        Form {
            Section {
                ForEach(AppAction.shortcutActions) { action in
                    LabeledContent(action.title) {
                        HStack {
                            ShortcutRecorder(combo: binding(action), inUse: inUse(except: action))
                                .frame(width: 160, height: 24)
                            if let error = controller.shortcutErrors[action] {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .help(error)
                            }
                            Button("Default") { controller.settings.reset(action.shortcutKey) }
                                .disabled(controller.settings[action.shortcutKey] == action.defaultShortcut)
                        }
                    }
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Click a field, then type the combination. Esc cancels, Delete clears. ⚠︎ means another app already uses it.")
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ action: AppAction) -> Binding<KeyCombo?> {
        controller.settings.binding(action.shortcutKey)
    }

    private func inUse(except action: AppAction) -> [KeyCombo: String] {
        var used: [KeyCombo: String] = [:]
        for other in AppAction.shortcutActions where other != action {
            if let combo = controller.settings[other.shortcutKey] {
                used[combo] = other.title
            }
        }
        return used
    }
}
