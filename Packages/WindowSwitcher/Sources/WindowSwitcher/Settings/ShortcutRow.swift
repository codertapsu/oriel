import Hotkeys
import OrielCore
import SwiftUI

/// One shortcut in Settings: its preset and its combination, recorded with `ShortcutRecorder` (⌘⇥ and ⌘⇧⇥
/// allowed), and, disclosed, its reverse modifier, release behaviour, style, filters and order. The preset picker
/// sets the apps and screens filters and the order; changing those by hand can make the shortcut Custom.
struct ShortcutRow: View {
    let number: Int
    @Binding var shortcut: ShortcutSpec
    /// The other shortcuts' combinations, so the recorder flags conflicts.
    let inUse: [KeyCombo: String]
    let onRemove: () -> Void

    private static let reverseChoices: [(String, KeyCombo.Modifiers?)] = [
        ("None", nil), ("⇧ Shift", .shift), ("⌃ Control", .control), ("⌥ Option", .option), ("⌘ Command", .command),
    ]

    var body: some View {
        DisclosureGroup {
            Picker("Step back with", selection: $shortcut.reverseModifier) {
                ForEach(Self.reverseChoices, id: \.0) { title, modifier in
                    Text(title).tag(modifier)
                }
            }
            Picker("When the keys are released", selection: $shortcut.releaseBehavior) {
                ForEach(ReleaseBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            Picker("Style", selection: $shortcut.style) {
                Text("Default").tag(DisplayStyle?.none)
                ForEach(DisplayStyle.allCases) { style in
                    Text(style.title).tag(DisplayStyle?.some(style))
                }
            }
            Picker("Apps", selection: $shortcut.filter.apps) {
                Text("All apps").tag(WindowFilter.Apps.all)
                Text("Active app only").tag(WindowFilter.Apps.active)
            }
            Picker("Screens", selection: $shortcut.filter.screens) {
                Text("All screens").tag(WindowFilter.Scope.all)
                // "Show on" in Appearance decides which display that is.
                Text("The screen it opens on").tag(WindowFilter.Scope.current)
            }
            Picker("Order", selection: $shortcut.grouping) {
                ForEach(WindowGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
            Picker("Spaces", selection: $shortcut.filter.spaces) {
                Text("All Spaces").tag(WindowFilter.Scope.all)
                Text("Current Space only").tag(WindowFilter.Scope.current)
            }
            Picker("Minimized windows", selection: $shortcut.filter.minimized) {
                Text("Show").tag(WindowFilter.Inclusion.include)
                Text("Hide").tag(WindowFilter.Inclusion.exclude)
            }
            Picker("Windows of hidden apps", selection: $shortcut.filter.hidden) {
                Text("Show").tag(WindowFilter.Inclusion.include)
                Text("Hide").tag(WindowFilter.Inclusion.exclude)
            }
            Button("Remove Shortcut", role: .destructive, action: onRemove)
        } label: {
            HStack {
                Toggle("Shortcut \(number)", isOn: $shortcut.isEnabled)
                Spacer()
                // A fixed width, so every row's switch, preset and combination line up in columns.
                presetPicker
                    .frame(width: 210, alignment: .trailing)
                ShortcutRecorder(
                    combo: combo,
                    allowed: [ReservedShortcuts.commandTab, CommandTabTakeover.commandShiftTab],
                    inUse: inUse
                )
                .frame(width: 150)
            }
        }
    }

    /// What the shortcut lists, next to its combination. Custom appears only while the filters match no preset.
    private var presetPicker: some View {
        Picker("Shows", selection: $shortcut.preset) {
            ForEach(SwitcherPreset.allCases) { preset in
                Text(preset.title).tag(SwitcherPreset?.some(preset))
            }
            if shortcut.preset == nil {
                Divider()
                Text("Custom").tag(SwitcherPreset?.none)
            }
        }
        .labelsHidden()
        .help("What this shortcut lists. Open the row to fine-tune it.")
        .accessibilityLabel("Shortcut \(number) shows")
    }

    /// Clearing the recorder turns the shortcut off and keeps its last combination.
    private var combo: Binding<KeyCombo?> {
        Binding(
            get: { shortcut.trigger },
            set: { newValue in
                if let newValue {
                    shortcut.trigger = newValue
                    shortcut.isEnabled = true
                } else {
                    shortcut.isEnabled = false
                }
            }
        )
    }
}
