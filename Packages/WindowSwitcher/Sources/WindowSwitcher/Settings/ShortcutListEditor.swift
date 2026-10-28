import OrielCore
import SwiftUI

/// The shortcuts table: up to nine `ShortcutRow`s, add and remove.
struct ShortcutListEditor: View {
    @Binding var shortcuts: [ShortcutSpec]

    var body: some View {
        ForEach(Array(shortcuts.indices), id: \.self) { index in
            ShortcutRow(number: index + 1, shortcut: shortcut(at: index), inUse: combos(except: index)) {
                guard shortcuts.indices.contains(index) else { return }
                shortcuts.remove(at: index)
            }
        }
        Button("Add Shortcut") {
            shortcuts.append(ShortcutSpec(
                holdModifiers: .option,
                nextKey: KeyCode.grave,
                reverseModifier: .shift,
                filter: WindowFilter(apps: .active)
            ))
        }
        .disabled(shortcuts.count >= ShortcutSpec.maximumCount)
    }

    /// Bounds-checked, because a row can outlive its index for a moment after a removal.
    private func shortcut(at index: Int) -> Binding<ShortcutSpec> {
        Binding(
            get: { shortcuts.indices.contains(index) ? shortcuts[index] : .optionTab },
            set: { newValue in
                guard shortcuts.indices.contains(index) else { return }
                shortcuts[index] = newValue.normalized()
            }
        )
    }

    private func combos(except index: Int) -> [KeyCombo: String] {
        var combos: [KeyCombo: String] = [:]
        for (position, shortcut) in shortcuts.enumerated() where position != index && shortcut.isEnabled {
            combos[shortcut.trigger] = "Shortcut \(position + 1)"
            if let reverse = shortcut.reverseTrigger {
                combos[reverse] = "Shortcut \(position + 1), backwards"
            }
        }
        return combos
    }
}
