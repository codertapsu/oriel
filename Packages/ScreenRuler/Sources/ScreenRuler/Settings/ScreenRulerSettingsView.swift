import AppKit
import OrielCore
import SwiftUI

/// Settings → Screen Ruler: the mode and unit it opens with, the color it draws in, and how readily Dimensions finds
/// an edge.
struct ScreenRulerSettingsView: View {
    let model: ScreenRulerSettingsModel

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Screen Ruler") {
                if !model.isActive {
                    Text("Screen Ruler is off. Turn it on in General → Tools.").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Open the ruler with") {
                    Text(model.shortcut ?? "No shortcut").foregroundStyle(.secondary)
                }
                Text(Self.keysNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Picker("Open in", selection: settings.binding(RulerSettings.defaultMode)) {
                    ForEach(RulerMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Measure in", selection: settings.binding(RulerSettings.unit)) {
                    ForEach(RulerUnit.allCases) { Text($0.title).tag($0) }
                }
                Text("On a Retina display one point is two pixels. U switches while measuring.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker("Line color", selection: colorBinding(settings), supportsOpacity: false)
                Text("Guides and measurements are drawn in this color.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Dimensions") {
                LabeledContent("Edge tolerance") {
                    HStack {
                        // Whole percents through the binding: a `step` would draw fifty tick marks.
                        Slider(value: toleranceBinding(settings), in: 0 ... Double(RulerSettings.toleranceRange.upperBound))
                            .frame(width: 180)
                            .accessibilityLabel("Edge tolerance")
                            .accessibilityValue("\(settings[RulerSettings.tolerance]) percent")
                        Text("\(settings[RulerSettings.tolerance])%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Text(Self.toleranceNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                LabeledContent("Screen Recording") {
                    HStack {
                        Text(model.screenRecording == .granted ? "Allowed" : "Not allowed")
                            .foregroundStyle(model.screenRecording == .granted ? Color.secondary : Color.orange)
                        if model.screenRecording != .granted, model.canAskForScreenRecording {
                            Button("Open System Settings") { model.openScreenRecordingSettings() }
                        }
                    }
                }
                Text(Self.permissionNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refresh() }
    }

    private func colorBinding(_ settings: SettingsStore) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: RulerColor.color(hex: settings[RulerSettings.guideColor]) ?? RulerColor.fallback) },
            set: { settings[RulerSettings.guideColor] = RulerColor.hex(of: NSColor($0)) }
        )
    }

    private func toleranceBinding(_ settings: SettingsStore) -> Binding<Double> {
        Binding(
            get: { Double(settings[RulerSettings.tolerance]) },
            set: { value in
                let percent = Int(value.rounded())
                if percent != settings[RulerSettings.tolerance] {
                    settings[RulerSettings.tolerance] = percent
                }
            }
        )
    }

    private static let keysNote = """
    Change the shortcut in Settings → Shortcuts. While measuring, Tab or 1–3 switch modes, ⌘C copies the measurement, \
    Return copies it and closes, and Esc closes.
    """

    private static let toleranceNote = """
    How different two neighbouring pixels must be to count as an edge. Lower it to find faint edges; raise it when \
    noise, shadows or gradients stop the lines short. [ and ] change it while measuring.
    """

    private static let permissionNote = """
    Dimensions finds edges in a still picture of the screen, taken when the ruler opens, which needs Screen & System \
    Audio Recording. Measure Area and Guides work without it.
    """
}
