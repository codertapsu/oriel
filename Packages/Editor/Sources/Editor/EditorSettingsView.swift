import AppKit
import OrielCore
import SwiftUI

/// The editor's settings pane: default colour, stroke width, export format and background preset. New editor
/// windows start from these.
public struct EditorSettingsView: View {
    @Bindable private var settings: SettingsStore

    /// - Parameter settings: the store the values are read from and written to.
    public init(settings: SettingsStore) {
        _settings = Bindable(settings)
    }

    public var body: some View {
        Form {
            Section("Annotations") {
                ColorPicker("Default colour", selection: defaultColor, supportsOpacity: false)
                LabeledContent("Stroke width") {
                    HStack {
                        Slider(
                            value: $settings[EditorSettings.strokeWidth],
                            in: Double(ToolStyle.widthRange.lowerBound) ... Double(ToolStyle.widthRange.upperBound),
                            step: 1
                        )
                        .accessibilityLabel("Stroke width")
                        Text("\(Int(settings[EditorSettings.strokeWidth])) pt")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Section("Output") {
                Picker("Export format", selection: $settings[EditorSettings.exportFormat]) {
                    ForEach(EditorExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                Picker("Background", selection: $settings[EditorSettings.backgroundPreset]) {
                    ForEach(BackgroundPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var defaultColor: Binding<Color> {
        Binding(
            get: { Color(cgColor: settings[EditorSettings.defaultColor].cgColor) },
            set: { newValue in
                if let color = RGBAColor(NSColor(newValue)) {
                    settings[EditorSettings.defaultColor] = color
                }
            }
        )
    }
}
