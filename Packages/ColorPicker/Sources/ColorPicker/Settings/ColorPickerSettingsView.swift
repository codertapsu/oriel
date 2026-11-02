import OrielCore
import SwiftUI

/// Settings → Color Picker: what a pick copies and in which format, how HEX is written, and how many recent colors
/// are kept.
struct ColorPickerSettingsView: View {
    let model: ColorPickerSettingsModel

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Color Picker") {
                if !model.isActive {
                    Text("Color Picker is off. Turn it on in General → Tools.").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Pick a color with") {
                    Text(model.shortcut ?? "No shortcut").foregroundStyle(.secondary)
                }
                Text(Self.pickNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle("Copy the color as soon as it is picked", isOn: settings.binding(ColorPickerSettings.copiesOnPick))
                Picker("Copy as", selection: settings.binding(ColorPickerSettings.defaultFormat)) {
                    ForEach(ColorFormat.allCases) { format in
                        Text(format.isPro && !ProAccess.shared.isUnlocked ? "\(format.title) (Pro)" : format.title).tag(format)
                    }
                }
                Text(example(settings))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Toggle("Write HEX in capitals", isOn: settings.binding(ColorPickerSettings.uppercaseHex))
            }
            Section("Recent colors") {
                Picker("Keep the last", selection: settings.binding(ColorPickerSettings.historySize)) {
                    ForEach(ColorPickerSettings.historySizeChoices, id: \.self) { Text("\($0) colors").tag($0) }
                }
                LabeledContent("Kept now") {
                    Text(keptNow).foregroundStyle(.secondary)
                }
                Button("Clear Recent Colors") { model.clearRecent() }
                    .disabled(model.recentCount == 0)
                Text("Palettes stay until you delete them.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refresh() }
    }

    private func example(_ settings: SettingsStore) -> String {
        let format = settings[ColorPickerSettings.defaultFormat]
        let text = ColorFormatter.string(format, for: model.exampleColor, uppercaseHex: settings[ColorPickerSettings.uppercaseHex])
        return "⌘C in the panel copies \(text)"
    }

    private var keptNow: String {
        let recent = model.recentCount == 1 ? "1 recent color" : "\(model.recentCount) recent colors"
        let palettes = model.paletteCount == 1 ? "1 palette" : "\(model.paletteCount) palettes"
        return "\(recent), \(palettes)"
    }

    private static let pickNote = """
    The loupe needs no permission: macOS shows it and gives Oriel only the color you click. Change the shortcut in \
    Settings → Shortcuts. In the panel, 1–9 and 0 copy the formats in the order listed.
    """
}
